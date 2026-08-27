"""CLI for application-facing Model 1 robustness checks."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.serving.demand_audit import audit_demand_serving


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Audit Model 1 inference on unseen and adversarial inputs"
    )
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--feature-contract", type=Path, required=True)
    parser.add_argument("--feature-suite-manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--sample-rows-per-role", type=int, default=5_000)
    parser.add_argument("--random-seed", type=int, default=20260821)
    args = parser.parse_args()
    output = audit_demand_serving(
        args.artifact_dir.resolve(),
        args.feature_contract.resolve(),
        args.feature_suite_manifest.resolve(),
        args.output.resolve(),
        sample_rows_per_role=args.sample_rows_per_role,
        random_seed=args.random_seed,
    )
    print(f"Serving audit: {output}")
