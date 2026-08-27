import json
from pathlib import Path

import pandas as pd
import pytest

from voltez_ml.config import load_config
from voltez_ml.features.availability import build_availability_features
from voltez_ml.features.builder import FeatureDataset, build_feature_dataset
from voltez_ml.features.demand import build_demand_features
from voltez_ml.features.splits import assign_purged_temporal_splits
from voltez_ml.synthetic.generator import GeneratedDataset, generate_dataset

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _read_generated(result: GeneratedDataset, table: str) -> pd.DataFrame:
    return pd.read_parquet(result.table_paths[table])


@pytest.fixture(scope="module")
def feature_fixture(
    tmp_path_factory: pytest.TempPathFactory,
) -> tuple[GeneratedDataset, FeatureDataset, FeatureDataset]:
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    root = tmp_path_factory.mktemp("features")
    generated = generate_dataset(config, PROJECT_ROOT, root / "source")
    first = build_feature_dataset(config, PROJECT_ROOT, [generated.output_dir], root / "first")
    second = build_feature_dataset(config, PROJECT_ROOT, [generated.output_dir], root / "second")
    return generated, first, second


def test_demand_target_is_exact_future_bucket(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    generated, features, _ = feature_fixture
    demand_features = pd.read_parquet(features.table_paths["demand_features"])
    expected = _read_generated(generated, "demand_buckets")[
        [
            "simulation_run_id",
            "zone_id",
            "bucket_start",
            "request_count",
        ]
    ].rename(
        columns={
            "bucket_start": "target_time",
            "request_count": "expected_target_request_count",
        }
    )
    checked = demand_features.merge(
        expected,
        on=["simulation_run_id", "zone_id", "target_time"],
        how="left",
        validate="many_to_one",
    )

    assert checked["expected_target_request_count"].notna().all()
    assert bool((checked["target_request_count"] == checked["expected_target_request_count"]).all())


def test_future_demand_mutation_changes_label_but_not_origin_features(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    generated, _, _ = feature_fixture
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    demand = _read_generated(generated, "demand_buckets")
    zones = _read_generated(generated, "zones")
    baseline = build_demand_features(config, demand, zones)
    origin = baseline.iloc[len(baseline) // 3]["prediction_origin"]
    mutated = demand.copy()
    mutated.loc[mutated["bucket_start"] >= origin, "request_count"] += 10_000
    changed = build_demand_features(config, mutated, zones)
    baseline_at_origin = baseline[baseline["prediction_origin"] == origin].sort_values(
        ["zone_id", "horizon_minutes"]
    )
    changed_at_origin = changed[changed["prediction_origin"] == origin].sort_values(
        ["zone_id", "horizon_minutes"]
    )
    non_label_columns = [
        column for column in baseline_at_origin.columns if column != "target_request_count"
    ]

    pd.testing.assert_frame_equal(
        baseline_at_origin[non_label_columns].reset_index(drop=True),
        changed_at_origin[non_label_columns].reset_index(drop=True),
    )
    assert bool(
        (
            baseline_at_origin["target_request_count"].to_numpy()
            != changed_at_origin["target_request_count"].to_numpy()
        ).any()
    )


def test_target_aligned_demand_lags_reference_the_exact_future_slot() -> None:
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    raw = pd.DataFrame(
        {
            "simulation_run_id": "run",
            "zone_id": "zone",
            "bucket_start": pd.date_range(
                "2026-01-01", periods=8 * 96, freq="15min", tz="Asia/Kolkata"
            ),
        }
    )
    raw["bucket_minutes"] = 15
    raw["request_count"] = range(len(raw))
    for column in (
        "search_count",
        "served_request_count",
        "no_candidate_count",
        "unserved_count",
        "booking_count",
        "session_count",
        "compatible_ports_listed",
        "compatible_ports_available",
    ):
        raw[column] = 0
    raw["occupancy_rate"] = 0.0
    zones = pd.DataFrame(
        {
            "simulation_run_id": ["run"],
            "zone_id": ["zone"],
            "centroid_latitude": [18.5204],
            "centroid_longitude": [73.8567],
            "zone_type": ["mixed"],
        }
    )

    features = build_demand_features(config, raw, zones)
    checked = features[features["request_lag_target_time_yesterday"].notna()].copy()
    checked["expected_time"] = checked["target_time"] - pd.Timedelta(1, unit="D")
    expected = raw[["bucket_start", "request_count"]].rename(
        columns={"bucket_start": "expected_time", "request_count": "expected_request_count"}
    )
    checked = checked.merge(expected, on="expected_time", validate="many_to_one")

    assert bool(
        (checked["request_lag_target_time_yesterday"] == checked["expected_request_count"]).all()
    )


def test_context_event_ingested_after_origin_cannot_change_that_prediction(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    generated, _, _ = feature_fixture
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    demand = _read_generated(generated, "demand_buckets")
    zones = _read_generated(generated, "zones")
    context = _read_generated(generated, "context_events")
    baseline = build_demand_features(config, demand, zones, context)
    sample = baseline.iloc[len(baseline) // 2]
    fake = context.iloc[0].copy()
    fake["context_event_id"] = "late-context-test"
    fake["simulation_run_id"] = sample["simulation_run_id"]
    fake["zone_id"] = sample["zone_id"]
    fake["event_type"] = "local_event_spike"
    fake["starts_at"] = sample["target_time"].normalize()
    fake["ends_at"] = fake["starts_at"] + pd.Timedelta(1, unit="D")
    fake["expected_impact"] = 9.0
    fake["published_at"] = sample["prediction_origin"] - pd.Timedelta(1, unit="D")
    fake["ingested_at"] = sample["prediction_origin"] + pd.Timedelta(1, unit="m")
    changed_context = pd.concat([context, fake.to_frame().T], ignore_index=True)
    changed = build_demand_features(config, demand, zones, changed_context)
    key = [
        "simulation_run_id",
        "zone_id",
        "prediction_origin",
        "horizon_minutes",
    ]
    selector = pd.Series(True, index=baseline.index)
    for column in key:
        selector &= baseline[column].eq(sample[column])
    changed_selector = pd.Series(True, index=changed.index)
    for column in key:
        changed_selector &= changed[column].eq(sample[column])

    pd.testing.assert_frame_equal(
        baseline.loc[selector].reset_index(drop=True),
        changed.loc[changed_selector].reset_index(drop=True),
    )

    fake["ingested_at"] = sample["prediction_origin"]
    known_context = pd.concat([context, fake.to_frame().T], ignore_index=True)
    known = build_demand_features(config, demand, zones, known_context)
    known_selector = pd.Series(True, index=known.index)
    for column in key:
        known_selector &= known[column].eq(sample[column])
    assert int(known.loc[known_selector, "context_event_count"].iloc[0]) == (
        int(baseline.loc[selector, "context_event_count"].iloc[0]) + 1
    )


def test_zone_type_is_exposed_only_as_numeric_model_features(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    _, features, _ = feature_fixture
    demand = pd.read_parquet(features.table_paths["demand_features"])

    assert "zone_type" not in demand.columns
    assert "zone_type_mixed" in demand.columns
    assert "zone_type_unknown" in demand.columns
    assert set(demand["zone_type_mixed"].unique()).issubset({0, 1})


def test_status_ingested_after_origin_cannot_change_that_prediction(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    generated, _, _ = feature_fixture
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    table_names = {
        "businesses",
        "business_hours",
        "chargers",
        "charger_ports",
        "connector_types",
        "bookings",
        "charging_sessions",
        "charger_status_events",
        "recommendation_impressions",
        "demand_buckets",
        "availability_observations",
    }
    tables = {name: _read_generated(generated, name) for name in table_names}
    baseline = build_availability_features(config, tables)
    sample = baseline.iloc[len(baseline) // 2]
    fake = tables["charger_status_events"].iloc[0].copy()
    fake["status_event_id"] = "future-ingestion-test"
    fake["charger_id"] = sample["charger_id"]
    fake["port_id"] = sample["port_id"]
    fake["status"] = "faulted"
    fake["confidence"] = 1.0
    fake["observed_at"] = sample["prediction_origin"] - pd.to_timedelta(5, unit="m")
    fake["ingested_at"] = sample["prediction_origin"] + pd.to_timedelta(1, unit="s")
    fake["expires_at"] = sample["prediction_origin"] + pd.to_timedelta(1, unit="h")
    tables["charger_status_events"] = pd.concat(
        [tables["charger_status_events"], fake.to_frame().T], ignore_index=True
    )
    changed = build_availability_features(config, tables)
    baseline_row = baseline[baseline["observation_id"] == sample["observation_id"]].reset_index(
        drop=True
    )
    changed_row = changed[changed["observation_id"] == sample["observation_id"]].reset_index(
        drop=True
    )

    pd.testing.assert_frame_equal(baseline_row, changed_row)


def test_unknown_labels_are_retained_but_excluded_from_supervised_table(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    _, features, _ = feature_fixture
    all_rows = pd.read_parquet(features.table_paths["availability_features_all"])
    labeled = pd.read_parquet(features.table_paths["availability_features_labeled"])

    assert bool((all_rows["label"] == "unknown").any())
    assert not bool((labeled["label"] == "unknown").any())
    assert len(labeled) == int((all_rows["label"] != "unknown").sum())

    waiting_all = pd.read_parquet(features.table_paths["waiting_time_features_all"])
    waiting_labeled = pd.read_parquet(features.table_paths["waiting_time_features_labeled"])
    reliability_all = pd.read_parquet(features.table_paths["reliability_features_all"])
    reliability_labeled = pd.read_parquet(features.table_paths["reliability_features_labeled"])
    assert len(waiting_labeled) == int((waiting_all["label_known"] == 1).sum())
    assert not bool(waiting_labeled["label_wait_minutes"].isna().any())
    assert bool((waiting_labeled["label_wait_minutes"] >= 0).all())
    assert len(reliability_labeled) == int((reliability_all["label"] != "unknown").sum())
    assert not bool((reliability_labeled["label"] == "unknown").any())


def test_feature_sources_and_split_targets_are_strictly_causal(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    _, features, _ = feature_fixture
    for table_name in (
        "demand_features",
        "availability_features_all",
        "waiting_time_features_all",
        "reliability_features_all",
    ):
        frame = pd.read_parquet(features.table_paths[table_name])
        assert bool((frame["latest_source_time"] <= frame["prediction_origin"]).all())
        assert bool((frame["target_time"] > frame["prediction_origin"]).all())
    demand = pd.read_parquet(features.table_paths["demand_features"])
    for _, run in demand.groupby("simulation_run_id"):
        train = run[run["split"] == "train"]
        validation = run[run["split"] == "validation"]
        test = run[run["split"] == "test"]
        assert train["target_time"].max() < validation["prediction_origin"].min()
        assert validation["target_time"].max() < test["prediction_origin"].min()


def test_label_context_and_current_bucket_truth_are_not_features(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    _, features, _ = feature_fixture
    demand = pd.read_parquet(features.table_paths["demand_features"])
    availability = pd.read_parquet(features.table_paths["availability_features_all"])

    assert "request_count" not in demand.columns
    assert "booking_state" not in availability.columns
    assert "port_status" not in availability.columns
    assert not any(column.startswith("latent_") for column in [*demand, *availability])


def test_service_feature_labels_match_raw_observations(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    generated, features, _ = feature_fixture
    waiting = pd.read_parquet(features.table_paths["waiting_time_features_all"])
    raw_waiting = _read_generated(generated, "waiting_time_observations")
    checked_waiting = waiting.merge(
        raw_waiting[["waiting_observation_id", "label_wait_minutes"]],
        on="waiting_observation_id",
        suffixes=("_feature", "_raw"),
        validate="one_to_one",
    )
    pd.testing.assert_series_equal(
        checked_waiting["label_wait_minutes_feature"],
        checked_waiting["label_wait_minutes_raw"],
        check_names=False,
    )

    reliability = pd.read_parquet(features.table_paths["reliability_features_all"])
    raw_reliability = _read_generated(generated, "reliability_observations")
    checked_reliability = reliability.merge(
        raw_reliability[["reliability_observation_id", "label"]],
        on="reliability_observation_id",
        suffixes=("_feature", "_raw"),
        validate="one_to_one",
    )
    assert bool((checked_reliability["label_feature"] == checked_reliability["label_raw"]).all())


def test_feature_build_is_reproducible_and_reports_single_seed_limit(
    feature_fixture: tuple[GeneratedDataset, FeatureDataset, FeatureDataset],
) -> None:
    _, first, second = feature_fixture
    first_audit = json.loads(first.audit_path.read_text("utf-8"))

    assert first.feature_snapshot_id == second.feature_snapshot_id
    assert first.row_counts == second.row_counts
    assert first.reproducibility_fingerprint == second.reproducibility_fingerprint
    assert first_audit["status"] == "passed_with_warnings"
    assert any("cross-seed" in warning for warning in first_audit["warnings"])


def test_declared_experiment_roles_control_cross_seed_assignment() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    origins = pd.date_range("2026-01-01", periods=20, freq="15min", tz="Asia/Kolkata")
    targets = pd.date_range("2026-01-01 00:15", periods=20, freq="15min", tz="Asia/Kolkata")
    frames = []
    roles = {
        "run-train-a": "train",
        "run-train-b": "train",
        "run-validation": "validation",
        "run-test": "test",
        "run-stress": "stress_test",
    }
    for run_id in roles:
        frames.append(
            pd.DataFrame(
                {
                    "simulation_run_id": run_id,
                    "prediction_origin": origins,
                    "target_time": targets,
                }
            )
        )

    assigned, report = assign_purged_temporal_splits(
        pd.concat(frames, ignore_index=True),
        config.features.split,
        roles,
    )

    assert report["cross_seed"]["available"] is True
    assert report["cross_seed"]["assignment_source"] == "declared_experiment_roles"
    for run_id, role in roles.items():
        assert set(
            assigned.loc[
                assigned["simulation_run_id"] == run_id,
                "run_holdout_split",
            ]
        ) == {role}
    locked_test_world = assigned[assigned["simulation_run_id"] == "run-test"]
    assert set(locked_test_world["split"]) == {"train", "validation", "test"}
    assert set(locked_test_world["run_holdout_split"]) == {"test"}


def test_declared_roles_cannot_mix_with_development_runs() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    origins = pd.date_range("2026-01-01", periods=10, freq="15min", tz="Asia/Kolkata")
    targets = pd.date_range("2026-01-01 00:15", periods=10, freq="15min", tz="Asia/Kolkata")
    frame = pd.concat(
        [
            pd.DataFrame(
                {
                    "simulation_run_id": run_id,
                    "prediction_origin": origins,
                    "target_time": targets,
                }
            )
            for run_id in ("declared", "forgotten")
        ],
        ignore_index=True,
    )

    with pytest.raises(ValueError, match="cannot be mixed with development runs"):
        assign_purged_temporal_splits(
            frame,
            config.features.split,
            {"declared": "train"},
        )


def test_directory_sort_order_never_assigns_evaluation_roles() -> None:
    config = load_config(project_root=PROJECT_ROOT)
    origins = pd.date_range("2026-01-01", periods=10, freq="15min", tz="Asia/Kolkata")
    targets = pd.date_range("2026-01-01 00:15", periods=10, freq="15min", tz="Asia/Kolkata")
    frame = pd.concat(
        [
            pd.DataFrame(
                {
                    "simulation_run_id": run_id,
                    "prediction_origin": origins,
                    "target_time": targets,
                }
            )
            for run_id in ("a-run", "b-run", "c-run")
        ],
        ignore_index=True,
    )

    assigned, report = assign_purged_temporal_splits(frame, config.features.split)

    assert set(assigned["run_holdout_split"]) == {"not_available"}
    assert report["cross_seed"]["available"] is False
