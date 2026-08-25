"""Typed Parquet output and reproducibility manifests."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import pandas as pd

from voltez_ml.synthetic.randomness import canonical_json, stable_hash


def dataframe_schema_hash(frame: pd.DataFrame) -> str:
    """Hash ordered column names and dtypes so schema changes are visible."""

    schema = [{"name": column, "dtype": str(frame[column].dtype)} for column in frame.columns]
    return stable_hash(schema)


def file_sha256(path: Path) -> str:
    """Hash a file without loading it entirely into memory."""

    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def write_tables(tables: dict[str, pd.DataFrame], output_dir: Path) -> dict[str, dict[str, Any]]:
    """Write sorted tables and return immutable file metadata."""

    output_dir.mkdir(parents=True, exist_ok=False)
    metadata: dict[str, dict[str, Any]] = {}
    for name in sorted(tables):
        path = output_dir / f"{name}.parquet"
        tables[name].to_parquet(path, engine="pyarrow", index=False, compression="zstd")
        metadata[name] = {
            "path": path.name,
            "rows": len(tables[name]),
            "columns": list(tables[name].columns),
            "schema_hash": dataframe_schema_hash(tables[name]),
            "sha256": file_sha256(path),
        }
    return metadata


def write_manifest(manifest: dict[str, Any], path: Path) -> None:
    """Write human-readable canonical manifest JSON."""

    path.write_text(json.dumps(manifest, sort_keys=True, indent=2, default=str) + "\n", "utf-8")


def reproducibility_fingerprint(table_metadata: dict[str, dict[str, Any]]) -> str:
    """Hash dataset content metadata while excluding machine-specific paths and timestamps."""

    stable_metadata = {
        table: {
            "rows": values["rows"],
            "columns": values["columns"],
            "schema_hash": values["schema_hash"],
            "sha256": values["sha256"],
        }
        for table, values in sorted(table_metadata.items())
    }
    return hashlib.sha256(canonical_json(stable_metadata).encode("utf-8")).hexdigest()
