"""CLI for promoting the selected Model 1 artifact into a deployment bundle."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.serving.promotion import promote_demand_model


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build a verified, self-contained Model 1 deployment bundle"
    )
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--feature-contract", type=Path, required=True)
    parser.add_argument("--selection-manifest", type=Path, required=True)
    parser.add_argument("--robustness-audit", type=Path, required=True)
    parser.add_argument("--locked-test-report", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    output = promote_demand_model(
        args.artifact_dir.resolve(),
        args.feature_contract.resolve(),
        args.selection_manifest.resolve(),
        args.robustness_audit.resolve(),
        args.locked_test_report.resolve(),
        args.output_dir.resolve(),
    )
    print(f"Deployment bundle: {output}")
