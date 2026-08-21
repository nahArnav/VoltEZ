import json
from pathlib import Path

import pandas as pd
import pytest

from voltez_ml.config import VoltEZConfig, load_config
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
    route_requests = requests[requests["request_type"] == "route_planning"]

    assert not route_requests.empty
    assert set(route_requests["trip_id"]) == set(trips["trip_id"])
    assert set(options["trip_id"]).issubset(set(trips["trip_id"]))
    assert bool((options["estimated_detour_km"] >= 0).all())
    assert bool((options["estimated_total_cost"] >= 0).all())


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


def test_known_availability_labels_match_exact_target_truth(
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
