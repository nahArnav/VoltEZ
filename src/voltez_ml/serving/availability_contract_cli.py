"""CLI for building Model 2's frozen application feature contract."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.serving.availability import build_availability_feature_contract


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build a training-only serving contract for Model 2"
    )
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--feature-suite-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    output = build_availability_feature_contract(
        args.artifact_dir.resolve(),
        args.feature_suite_manifest.resolve(),
        args.output.resolve(),
    )
    print(f"Feature contract: {output}")
