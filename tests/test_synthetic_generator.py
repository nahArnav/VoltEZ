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
    assert "pending" not in set(requests["request_status"])
    assert {"served", "no_candidate"}.issubset(set(requests["request_status"]))


def test_unknown_availability_remains_null_and_is_not_false(
    generated_pair: tuple[GeneratedDataset, GeneratedDataset],
) -> None:
    result, _ = generated_pair
    observations = _read(result, "availability_observations")
    latent = _read(result, "qa_latent_availability")
    joined = observations.merge(latent[["observation_id", "latent_available"]], on="observation_id")

    unknown = joined[joined["availability_label"].isna()]
    assert not unknown.empty
    assert bool(unknown["latent_available"].any())
    assert set(observations["availability_label"].dropna().astype(bool)) == {True, False}


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


def test_safety_limit_rejects_an_oversized_plan(tmp_path: Path) -> None:
    config = load_config(
        environment="test", synthetic_profile="pune_test", project_root=PROJECT_ROOT
    )
    values = config.model_dump()
    values["synthetic"]["safeguards"]["maximum_generated_rows"] = 10
    unsafe_config = VoltEZConfig.model_validate(values)

    with pytest.raises(ValueError, match="above safety limit"):
        generate_dataset(unsafe_config, project_root=PROJECT_ROOT, output_root=tmp_path)
