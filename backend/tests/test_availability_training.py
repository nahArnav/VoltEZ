import json
from pathlib import Path
from typing import Any

import joblib  # type: ignore[import-untyped]
import numpy as np
import pandas as pd
import pytest

from voltez_ml.synthetic.io import file_sha256, write_manifest
from voltez_ml.training.availability import (
    AvailabilityTrainingSettings,
    _decision_metrics,
    _feature_spec,
    _load_role,
    _select_thresholds,
    train_availability_model,
)

pytestmark = [
    pytest.mark.filterwarnings("ignore:Could not find the number of physical cores:UserWarning"),
    pytest.mark.filterwarnings("ignore:Setting the shape on a NumPy array:DeprecationWarning"),
]


def _availability_frame(role: str, world: str, seed: int, rows: int = 180) -> pd.DataFrame:
    rng = np.random.default_rng(seed)
    eta = rng.choice([15.0, 30.0, 60.0, 120.0], size=rows)
    status = rng.choice(
        ["available", "occupied", "faulted"],
        size=rows,
        p=[0.72, 0.23, 0.05],
    )
    expired = rng.binomial(1, 0.65, size=rows)
    active = rng.binomial(1, 0.18, size=rows)
    logit = (
        -3.2
        + 1.15 * active
        + 0.012 * eta
        + 1.0 * (status == "occupied")
        + 2.0 * (status == "faulted")
        - 0.45 * expired
    )
    unavailable_probability = 1 / (1 + np.exp(-logit))
    unavailable = rng.random(rows) < unavailable_probability
    unavailable[0] = False
    unavailable[1] = True
    return pd.DataFrame(
        {
            "simulation_run_id": world,
            "run_holdout_split": role,
            "label": np.where(unavailable, "unavailable", "available"),
            "label_confidence": np.where(unavailable, 0.98, 0.99),
            "eta_minutes": eta,
            "target_hour_sin": rng.uniform(-1, 1, size=rows),
            "active_session_count": active,
            "active_session_elapsed_minutes": active * rng.uniform(0, 90, size=rows),
            "status_expired": expired,
            "latest_status": status,
            "latest_status_source": rng.choice(["owner", "driver_report"], size=rows),
            "reliability_cold_start": rng.binomial(1, 0.1, size=rows),
            "recent_zone_occupancy_mean_1h": rng.uniform(0, 1, size=rows),
            "connector_code": rng.choice(["ccs2", "type_2"], size=rows),
        }
    )


def _suite(tmp_path: Path) -> Path:
    data_root = tmp_path / "data"
    data_root.mkdir()
    entries: list[dict[str, Any]] = []
    definitions = [
        ("train", "train-a", 1),
        ("train", "train-b", 2),
        ("validation", "validation-a", 3),
        ("stress_test", "stress-a", 4),
    ]
    for role, world, seed in definitions:
        path = data_root / f"{world}.parquet"
        _availability_frame(role, world, seed).to_parquet(path, index=False)
        entries.append(
            {
                "evaluation_role": role,
                "run_id": world,
                "tables": {"availability_features_labeled": str(path)},
            }
        )
    # A nonexistent path proves the trainer does not open test data during development.
    entries.append(
        {
            "evaluation_role": "test",
            "run_id": "locked-test",
            "tables": {
                "availability_features_labeled": str(data_root / "must-not-open.parquet")
            },
        }
    )
    readiness_path = tmp_path / "training_readiness.json"
    write_manifest(
        {
            "models": {"availability": {"status": "ready", "failures": []}},
        },
        readiness_path,
    )
    manifest_path = tmp_path / "feature_suite_manifest.json"
    write_manifest(
        {
            "training_readiness": {
                "path": readiness_path.name,
                "sha256": file_sha256(readiness_path),
            },
            "datasets": entries,
        },
        manifest_path,
    )
    return manifest_path


def test_feature_contract_excludes_identity_and_label_columns() -> None:
    frame = _availability_frame("train", "world", 10)
    frame["request_id"] = [f"request-{index}" for index in range(len(frame))]
    frame["service_ready_at"] = pd.Timestamp("2026-01-01", tz="Asia/Kolkata")

    spec = _feature_spec(frame)

    assert "request_id" not in spec.all
    assert "service_ready_at" not in spec.all
    assert "label_confidence" not in spec.all
    assert "eta_minutes" in spec.numeric
    assert "latest_status" in spec.categorical


def test_thresholds_create_an_explicit_unknown_band() -> None:
    truth = np.array([0] * 80 + [1] * 20, dtype="int64")
    probability = np.linspace(0.001, 0.95, 100, dtype="float64")
    settings = AvailabilityTrainingSettings(minimum_threshold_rows=5)

    thresholds = _select_thresholds(truth, probability, settings)
    metrics = _decision_metrics(truth, probability, thresholds)

    assert (
        thresholds["available_max_probability_unavailable"]
        < thresholds["unavailable_min_probability_unavailable"]
    )
    assert metrics["counts"]["unknown"] > 0
    assert 0 < metrics["coverage"] < 1


def test_locked_test_role_is_rejected_before_file_access(tmp_path: Path) -> None:
    manifest_path = _suite(tmp_path)
    suite = json.loads(manifest_path.read_text("utf-8"))
    suite["_manifest_root"] = str(tmp_path)

    with pytest.raises(ValueError, match="locked test access is forbidden"):
        _load_role(suite, "test")


def test_end_to_end_training_uses_train_validation_and_stress_only(
    tmp_path: Path,
) -> None:
    manifest_path = _suite(tmp_path)
    output = train_availability_model(
        manifest_path,
        tmp_path / "artifacts",
        AvailabilityTrainingSettings(
            max_iter=25,
            learning_rate=0.1,
            max_leaf_nodes=7,
            min_samples_leaf=10,
            minimum_threshold_rows=5,
            permutation_sample_rows=100,
            permutation_repeats=1,
            random_seed=22,
        ),
    )

    report = json.loads((output / "evaluation_report.json").read_text("utf-8"))
    artifact = joblib.load(output / "model.joblib")

    assert report["locked_test_accessed"] is False
    assert report["training_worlds"] == 2
    assert report["calibration"]["uses_validation_labels"] is False
    assert report["validation"]["rows"] == 180
    assert report["stress_test"]["rows"] == 180
    assert artifact["positive_class"] == "unavailable"
    assert artifact["missing_status_policy"] == "unknown"
