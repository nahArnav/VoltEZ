import json
from pathlib import Path

import pandas as pd
import pytest

from voltez_ml.config import VoltEZConfig, load_config
from voltez_ml.synthetic.entities import generate_static_entities
from voltez_ml.synthetic.generator import GeneratedDataset, generate_dataset

PROJECT_ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def generated_pair(
    tmp_path_factory: pytest.TempPathFactory,
) -> tuple[GeneratedDataset, GeneratedDataset]:
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    root = tmp_path_factory.mktemp("synthetic")
    first = generate_dataset(config, project_root=PROJECT_ROOT, output_root=root / "first")
    second = generate_dataset(config, project_root=PROJECT_ROOT, output_root=root / "second")
    return first, second


def _read(result: GeneratedDataset, table: str) -> pd.DataFrame:
    return pd.read_parquet(result.table_paths[table])


def _without_run_lineage(frame: pd.DataFrame) -> pd.DataFrame:
    return frame.drop(columns="simulation_run_id").reset_index(drop=True)


def test_test_profile_builds_complete_fifteen_minute_grid(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    demand = _read(result, "demand_buckets")

    assert len(demand) == 4 * 2 * 96
    assert set(demand["bucket_minutes"]) == {15}
    assert int(demand["request_count"].sum()) == result.row_counts["charging_requests"]


def test_requests_not_bookings_are_the_primary_demand_truth(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    requests = _read(result, "charging_requests")
    bookings = _read(result, "bookings")

    assert len(requests) > len(bookings)
    assert "pending" not in set(requests["result_status"])
    assert {"served", "no_candidate"}.issubset(set(requests["result_status"]))


def test_unknown_availability_remains_explicit_and_is_not_unavailable(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    observations = _read(result, "availability_observations")
    latent = _read(result, "qa_latent_availability")
    joined = observations.merge(latent[["observation_id", "latent_available"]], on="observation_id")

    unknown = joined[joined["label"] == "unknown"]
    assert not unknown.empty
    assert bool(unknown["latent_available"].any())
    assert set(observations["label"]) == {"available", "unavailable", "unknown"}


def test_schema_v1_1_normalized_relationships_are_materialized(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    manifest = json.loads(result.manifest_path.read_text("utf-8"))
    table_names = set(manifest["tables"])

    assert manifest["experiment"] == {
        "name": "development",
        "evaluation_role": "development",
    }
    assert manifest["seed"] == manifest["dynamic_seed"]
    assert manifest["structural_seed"] == 20260821
    assert manifest["structural_namespace"].startswith("structure:pune:")

    assert {
        "users",
        "connector_types",
        "business_hour_exceptions",
        "amenities",
        "business_amenities",
        "business_offers",
        "tariffs",
        "trips",
        "trip_charger_options",
        "waiting_time_observations",
        "reliability_observations",
        "qa_latent_port_profiles",
    }.issubset(table_names)
    ports = _read(result, "charger_ports")
    parking = _read(result, "parking_spaces")
    assert {"charger_id", "connector_type_id", "port_number", "current_status"}.issubset(
        ports.columns
    )
    assert "parking_space_id" not in ports.columns
    assert "charger_id" in parking.columns


def test_route_requests_are_linked_to_trips_and_options(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    requests = _read(result, "charging_requests")
    trips = _read(result, "trips")
    options = _read(result, "trip_charger_options")
    vehicles = _read(result, "vehicles")
    route_requests = requests[requests["request_type"] == "route_planning"]

    assert not route_requests.empty
    request_trip_ids = set(route_requests["trip_id"])
    all_trip_ids = set(trips["trip_id"])
    assert request_trip_ids.issubset(all_trip_ids)
    assert len(all_trip_ids - request_trip_ids) == len(vehicles)
    assert set(options["trip_id"]).issubset(set(trips["trip_id"]))
    assert bool((options["estimated_detour_km"] >= 0).all())
    assert bool((options["estimated_total_cost"] >= 0).all())


def test_route_energy_profiles_cover_every_vehicle_with_public_priors(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    vehicles = _read(result, "vehicles")
    profiles = _read(result, "vehicle_energy_profiles")

    assert len(profiles) == len(vehicles)
    assert profiles["vehicle_id"].is_unique
    assert set(profiles["vehicle_id"]) == set(vehicles["vehicle_id"])
    assert set(profiles["source"]).issubset(
        {"catalogue", "owner_declared", "class_default"}
    )
    assert bool(profiles["confidence"].between(0, 1).all())
    assert bool(profiles["drivetrain_efficiency"].between(0.5, 1).all())
    assert bool(profiles["usable_capacity_fraction"].between(0.5, 1).all())
    assert bool(profiles["battery_health_fraction"].between(0.5, 1).all())


def test_route_snapshots_cover_direct_and_candidate_legs_without_broken_links(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    trips = _read(result, "trips")
    options = _read(result, "trip_charger_options")
    snapshots = _read(result, "route_snapshots")

    assert len(snapshots) == len(trips) + len(options)
    assert snapshots["route_snapshot_id"].is_unique
    direct = trips[["trip_id", "direct_route_snapshot_id"]].merge(
        snapshots,
        left_on="direct_route_snapshot_id",
        right_on="route_snapshot_id",
        validate="one_to_one",
    )
    assert bool((direct["trip_id_x"] == direct["trip_id_y"]).all())
    assert set(direct["leg_type"]) == {"destination"}
    assert bool(direct["candidate_charger_id"].isna().all())

    candidates = options[["trip_id", "charger_id", "route_snapshot_id"]].merge(
        snapshots,
        on="route_snapshot_id",
        validate="one_to_one",
    )
    assert bool((candidates["trip_id_x"] == candidates["trip_id_y"]).all())
    assert bool((candidates["charger_id"] == candidates["candidate_charger_id"]).all())
    assert set(candidates["leg_type"]) == {"candidate_charger"}


def test_route_snapshot_context_is_point_in_time_and_explicitly_missing(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    snapshots = _read(result, "route_snapshots")

    assert bool((snapshots["requested_at"] <= snapshots["route_snapshot_at"]).all())
    assert bool((snapshots["route_snapshot_at"] < snapshots["expires_at"]).all())
    assert bool(
        (snapshots["traffic_duration_minutes"] >= snapshots["normal_duration_minutes"]).all()
    )
    assert bool(
        (snapshots["urban_fraction"] + snapshots["highway_fraction"])
        .sub(1.0)
        .abs()
        .le(0.00001)
        .all()
    )

    missing_weather = snapshots["weather_source_quality"] == "missing"
    assert bool(missing_weather.any())
    assert bool(snapshots.loc[missing_weather, "ambient_temperature_c"].isna().all())
    known_weather = snapshots.loc[~missing_weather]
    assert bool((known_weather["weather_ingested_at"] <= known_weather["route_snapshot_at"]).all())


def test_route_coverage_includes_highway_and_intercity_lengths(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    snapshots = _read(result, "route_snapshots")
    ordinary_journeys = snapshots[snapshots["request_id"].isna()]

    assert len(ordinary_journeys) == result.row_counts["vehicles"]
    assert float(ordinary_journeys["distance_km"].max()) > 100
    assert float(ordinary_journeys["urban_fraction"].min()) < 0.35
    assert float(ordinary_journeys["urban_fraction"].max()) > 0.75
    assert int((ordinary_journeys["distance_km"] >= 30).sum()) >= 20


def test_route_energy_step_two_contains_no_realized_energy_or_hidden_truth(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    manifest = json.loads(result.manifest_path.read_text("utf-8"))
    table_names = set(manifest["tables"])

    assert "route_energy_observations" not in table_names
    assert "qa_latent_route_energy" not in table_names
    for table_name in ("vehicle_energy_profiles", "route_snapshots"):
        columns = set(manifest["tables"][table_name]["columns"])
        assert not any(column.startswith(("qa_", "latent_", "actual_")) for column in columns)


def test_session_energy_matches_meter_delta(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    sessions = _read(result, "charging_sessions")
    completed = sessions[sessions["status"] == "completed"]
    meter_delta = completed["meter_end_kwh"] - completed["meter_start_kwh"]

    assert bool(((meter_delta - completed["energy_kwh"]).abs() <= 0.002).all())
    assert bool((completed["final_amount"] >= 0).all())


def test_demand_buckets_reconcile_without_double_counting_searches(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    demand = _read(result, "demand_buckets")
    requests = _read(result, "charging_requests")

    assert int(demand["request_count"].sum()) == len(requests)
    assert bool((demand["search_count"] <= demand["request_count"]).all())
    assert bool((demand["unserved_count"] <= demand["request_count"]).all())
    assert bool(demand["occupancy_rate"].between(0, 1).all())


def test_known_availability_labels_match_tolerance_aware_truth(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    observations = _read(result, "availability_observations")
    latent = _read(result, "qa_latent_availability")
    known = observations[observations["label"] != "unknown"].merge(
        latent[["observation_id", "latent_available"]], on="observation_id"
    )
    expected = known["latent_available"].map({True: "available", False: "unavailable"})

    assert not known.empty
    assert bool((known["label"] == expected).all())


def test_waiting_labels_reconcile_to_service_ready_evidence(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    waiting = _read(result, "waiting_time_observations")
    sessions = _read(result, "charging_sessions")
    known = waiting[waiting["label_known"] == 1].merge(
        sessions[["session_id", "check_in_at", "service_ready_at"]],
        on="session_id",
        validate="one_to_one",
    )
    expected = (
        known["service_ready_at"] - known["check_in_at"]
    ).dt.total_seconds() / 60

    assert not known.empty
    assert bool((expected >= 0).all())
    assert bool((known["label_wait_minutes"] - expected).abs().le(0.001).all())


def test_reliability_truth_excludes_congestion_failures(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    reliability = _read(result, "reliability_observations")
    sessions = _read(result, "charging_sessions")[["session_id", "status", "failure_reason"]]
    checked = reliability.merge(
        sessions,
        on="session_id",
        suffixes=("_observation", "_session"),
        validate="one_to_one",
    )
    expected = checked.apply(
        lambda row: (
            "reliable"
            if row["status"] == "completed"
            else "unreliable"
            if str(row["failure_reason_session"] or "").startswith("charger_fault")
            else "unknown"
        ),
        axis=1,
    )

    assert bool((checked["label"] == expected).all())
    congestion = checked[checked["failure_reason_session"] == "occupied_overrun"]
    assert bool((congestion["label"] == "unknown").all())


def test_latent_truth_never_appears_in_public_tables(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    manifest = json.loads(result.manifest_path.read_text("utf-8"))

    for table_name, metadata in manifest["tables"].items():
        if table_name.startswith("qa_latent_"):
            continue
        assert not any(column.startswith("latent_") for column in metadata["columns"])


def test_same_seed_and_configuration_produce_identical_content(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    first, second = generated_pair

    assert first.run_id == second.run_id
    assert first.snapshot_id == second.snapshot_id
    assert first.row_counts == second.row_counts
    assert first.reproducibility_fingerprint == second.reproducibility_fingerprint


def test_dynamic_seeds_share_one_physical_pune_network() -> None:
    train_config = load_config(
        environment="test",
        synthetic_profile="pune_test",
        experiment_profile="train_seed_01",
        project_root=PROJECT_ROOT,
    )
    validation_config = load_config(
        environment="test",
        synthetic_profile="pune_test",
        experiment_profile="validation_seed_01",
        project_root=PROJECT_ROOT,
    )
    train = generate_static_entities(train_config, "train-run")
    validation = generate_static_entities(validation_config, "validation-run")

    structural_tables = (
        "zones",
        "qa_latent_zones",
        "connector_types",
        "businesses",
        "business_hours",
        "amenities",
        "business_amenities",
        "business_offers",
        "chargers",
        "charger_ports",
        "qa_latent_port_profiles",
        "parking_spaces",
        "availability_windows",
        "tariffs",
    )
    for table_name in structural_tables:
        pd.testing.assert_frame_equal(
            _without_run_lineage(train[table_name]),
            _without_run_lineage(validation[table_name]),
        )

    train_drivers = train["users"].query("role == 'driver'")
    validation_drivers = validation["users"].query("role == 'driver'")
    assert set(train_drivers["user_id"]).isdisjoint(validation_drivers["user_id"])
    assert set(train["vehicles"]["vehicle_id"]).isdisjoint(
        validation["vehicles"]["vehicle_id"]
    )


def test_structural_shift_profile_creates_a_different_network() -> None:
    baseline_config = load_config(
        environment="test",
        synthetic_profile="pune_test",
        experiment_profile="validation_seed_01",
        project_root=PROJECT_ROOT,
    )
    shifted_config = load_config(
        environment="test",
        synthetic_profile="pune_test",
        experiment_profile="structural_shift_seed_01",
        project_root=PROJECT_ROOT,
    )
    baseline = generate_static_entities(baseline_config, "baseline-run")
    shifted = generate_static_entities(shifted_config, "shifted-run")

    assert set(baseline["zones"]["zone_id"]).isdisjoint(shifted["zones"]["zone_id"])
    assert set(baseline["charger_ports"]["port_id"]).isdisjoint(
        shifted["charger_ports"]["port_id"]
    )
    assert not baseline["qa_latent_zones"]["base_demand_multiplier"].equals(
        shifted["qa_latent_zones"]["base_demand_multiplier"]
    )


def test_declared_experiment_role_is_immutable_manifest_lineage(tmp_path: Path) -> None:
    development = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    locked_test = load_config(
        environment="test",
        synthetic_profile="pune_test",
        project_root=PROJECT_ROOT,
        experiment_profile="test_seed_01",
    )
    development_result = generate_dataset(
        development, project_root=PROJECT_ROOT, output_root=tmp_path / "development"
    )
    test_result = generate_dataset(
        locked_test, project_root=PROJECT_ROOT, output_root=tmp_path / "locked-test"
    )
    manifest = json.loads(test_result.manifest_path.read_text("utf-8"))

    assert test_result.run_id != development_result.run_id
    assert manifest["seed"] == 20261109
    assert manifest["experiment"] == {
        "name": "test_seed_01",
        "evaluation_role": "test",
    }


def test_safety_limit_rejects_an_oversized_plan(tmp_path: Path) -> None:
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    values = config.model_dump()
    values["synthetic"]["safeguards"]["maximum_generated_rows"] = 10
    unsafe_config = VoltEZConfig.model_validate(values)

    with pytest.raises(ValueError, match="above safety limit"):
        generate_dataset(unsafe_config, project_root=PROJECT_ROOT, output_root=tmp_path)
