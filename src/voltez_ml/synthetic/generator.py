"""Top-level orchestration for one reproducible VoltEZ synthetic dataset."""

from __future__ import annotations

import hashlib
import json
import subprocess
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pandas as pd

from voltez_ml.config import VoltEZConfig
from voltez_ml.synthetic.entities import generate_static_entities
from voltez_ml.synthetic.events import generate_event_tables
from voltez_ml.synthetic.io import (
    reproducibility_fingerprint,
    write_manifest,
    write_tables,
)
from voltez_ml.synthetic.randomness import config_fingerprint
from voltez_ml.synthetic.validation import (
    DatasetValidationError,
    estimate_planned_rows,
    validate_dataset,
)


@dataclass(frozen=True)
class GeneratedDataset:
    """Paths and identifiers returned to scripts, tests, and later training code."""

    run_id: str
    snapshot_id: str
    output_dir: Path
    manifest_path: Path
    table_paths: dict[str, Path]
    row_counts: dict[str, int]
    reproducibility_fingerprint: str


SORT_KEYS: dict[str, list[str]] = {
    "users": ["user_id"],
    "zones": ["zone_id"],
    "connector_types": ["connector_type_id"],
    "vehicle_connectors": ["vehicle_id", "connector_type_id"],
    "vehicles": ["vehicle_id"],
    "businesses": ["business_id"],
    "business_hours": ["business_id", "day_of_week"],
    "business_hour_exceptions": ["business_id", "date"],
    "amenities": ["amenity_id"],
    "business_amenities": ["business_id", "amenity_id"],
    "business_offers": ["business_id", "starts_at"],
    "chargers": ["charger_id"],
    "charger_ports": ["port_id"],
    "parking_spaces": ["parking_space_id"],
    "availability_windows": ["port_id", "start_at"],
    "tariffs": ["port_id", "starts_at"],
    "context_events": ["starts_at", "zone_id"],
    "charging_requests": ["requested_at", "request_id"],
    "trips": ["trip_id"],
    "trip_charger_options": ["trip_id", "rank"],
    "recommendation_impressions": ["shown_at", "request_id", "rank"],
    "bookings": ["created_at", "booking_id"],
    "booking_events": ["created_at", "booking_event_id"],
    "charging_sessions": ["arrived_at", "session_id"],
    "charger_status_events": ["observed_at", "status_event_id"],
    "demand_buckets": ["bucket_start", "zone_id"],
    "availability_observations": ["prediction_origin", "observation_id"],
    "waiting_time_observations": ["prediction_origin", "waiting_observation_id"],
    "reliability_observations": ["prediction_origin", "reliability_observation_id"],
    "qa_latent_demand": ["bucket_start", "zone_id"],
    "qa_latent_outages": ["start_at", "port_id"],
    "qa_latent_availability": ["observation_id"],
    "qa_latent_zones": ["zone_id"],
    "qa_latent_driver_profiles": ["user_id"],
    "qa_latent_port_profiles": ["port_id"],
}


def _sort_tables(tables: dict[str, pd.DataFrame]) -> dict[str, pd.DataFrame]:
    sorted_tables: dict[str, pd.DataFrame] = {}
    for name, frame in tables.items():
        keys = [key for key in SORT_KEYS.get(name, []) if key in frame.columns]
        sorted_tables[name] = (
            frame.sort_values(keys, kind="mergesort", na_position="last").reset_index(drop=True)
            if keys and not frame.empty
            else frame.reset_index(drop=True)
        )
    return sorted_tables


def _current_commit(project_root: Path) -> str | None:
    try:
        result = subprocess.run(
            ["/usr/bin/git", "rev-parse", "HEAD"],
            cwd=project_root,
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return result.stdout.strip() or None


def _code_is_dirty(project_root: Path) -> bool | None:
    try:
        result = subprocess.run(
            ["/usr/bin/git", "status", "--porcelain"],
            cwd=project_root,
            check=True,
            capture_output=True,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    return bool(result.stdout.strip())


def _generator_source_fingerprint(project_root: Path) -> str:
    """Hash generator source so code changes create a new simulation identity."""

    source_root = project_root / "src" / "voltez_ml" / "synthetic"
    digest = hashlib.sha256()
    source_paths = [*source_root.glob("*.py"), project_root / "src" / "voltez_ml" / "geography.py"]
    for path in sorted(source_paths):
        digest.update(str(path.relative_to(project_root)).encode("utf-8"))
        digest.update(path.read_bytes())
    return digest.hexdigest()


def _simulation_identity(config: VoltEZConfig, generator_source_hash: str) -> tuple[str, str, str]:
    identity_values = {
        "project_seed": config.project.seed,
        "experiment": config.experiment.model_dump(mode="json"),
        "city": config.project.city,
        "timezone": config.project.timezone,
        "time": config.time.model_dump(mode="json"),
        "synthetic": config.synthetic.model_dump(mode="json"),
        "feature_view_version": config.data.feature_view_version,
        "label_definition_version": config.data.label_definition_version,
        "generator_source_hash": generator_source_hash,
    }
    fingerprint = config_fingerprint(identity_values)
    return f"sim-{fingerprint[:16]}", f"snapshot-{fingerprint[:20]}", fingerprint


def generate_dataset(
    config: VoltEZConfig,
    project_root: Path,
    output_root: Path | None = None,
) -> GeneratedDataset:
    """Generate, validate, and materialize one versioned synthetic dataset."""

    planned_rows = estimate_planned_rows(config)
    if planned_rows > config.synthetic.safeguards.maximum_generated_rows:
        raise DatasetValidationError(
            f"planned generation estimates {planned_rows} rows, above safety limit "
            f"{config.synthetic.safeguards.maximum_generated_rows}"
        )
    generator_source_hash = _generator_source_fingerprint(project_root)
    run_id, snapshot_id, configuration_hash = _simulation_identity(config, generator_source_hash)
    static_tables = generate_static_entities(config, run_id)
    event_tables = generate_event_tables(config, run_id, snapshot_id, static_tables)
    tables = _sort_tables({**static_tables, **event_tables})
    validate_dataset(config, tables)

    destination_root = output_root or project_root / config.paths.data_root / "synthetic"
    destination_root.mkdir(parents=True, exist_ok=True)
    output_dir = destination_root / run_id
    incomplete_dir = destination_root / f".{run_id}.incomplete"
    previous_dir: Path | None = None
    if incomplete_dir.exists():
        raise FileExistsError(
            f"incomplete run exists at {incomplete_dir}; inspect it before trying again"
        )
    if output_dir.exists():
        if not config.data.overwrite_existing_run:
            raise FileExistsError(
                f"synthetic run already exists at {output_dir}; change the seed/profile or "
                "use an environment that explicitly permits replacement"
            )
        previous_dir = destination_root / f"{run_id}.previous"
        if previous_dir.exists():
            raise FileExistsError(
                f"recoverable backup already exists at {previous_dir}; inspect it before rerunning"
            )

    table_metadata = write_tables(tables, incomplete_dir)
    dataset_fingerprint = reproducibility_fingerprint(table_metadata)
    manifest = {
        "run_id": run_id,
        "snapshot_id": snapshot_id,
        "source_type": "synthetic",
        "generator_version": config.synthetic.generator_version,
        "seed": config.project.seed,
        "experiment": config.experiment.model_dump(mode="json"),
        "configuration_hash": configuration_hash,
        "generator_source_hash": generator_source_hash,
        "city": config.project.city,
        "timezone": config.project.timezone,
        "start_date": config.synthetic.start_date.isoformat(),
        "end_date_exclusive": (
            config.synthetic.start_date + timedelta(days=config.synthetic.days)
        ).isoformat(),
        "bucket_minutes": config.time.bucket_minutes,
        "feature_view_version": config.data.feature_view_version,
        "label_definition_version": config.data.label_definition_version,
        "code_commit": _current_commit(project_root),
        "code_is_dirty": _code_is_dirty(project_root),
        "materialized_at": datetime.now(UTC).isoformat(),
        "contains_personal_data": False,
        "qa_tables_are_forbidden_as_model_features": True,
        "tables": table_metadata,
        "row_counts": {name: len(frame) for name, frame in sorted(tables.items())},
        "reproducibility_fingerprint": dataset_fingerprint,
    }
    incomplete_manifest_path = incomplete_dir / "manifest.json"
    write_manifest(manifest, incomplete_manifest_path)

    if output_dir.exists() and config.synthetic.safeguards.require_reproducible_manifest:
        previous_manifest_path = output_dir / "manifest.json"
        if previous_manifest_path.exists():
            previous_manifest = json.loads(previous_manifest_path.read_text("utf-8"))
            previous_fingerprint = previous_manifest.get("reproducibility_fingerprint")
            if previous_fingerprint != dataset_fingerprint:
                raise RuntimeError(
                    "same configuration produced different dataset content; both runs were kept "
                    "for inspection"
                )

    if output_dir.exists() and previous_dir is not None:
        output_dir.rename(previous_dir)
    incomplete_dir.rename(output_dir)
    manifest_path = output_dir / "manifest.json"

    return GeneratedDataset(
        run_id=run_id,
        snapshot_id=snapshot_id,
        output_dir=output_dir,
        manifest_path=manifest_path,
        table_paths={name: output_dir / values["path"] for name, values in table_metadata.items()},
        row_counts={name: len(frame) for name, frame in tables.items()},
        reproducibility_fingerprint=dataset_fingerprint,
    )
