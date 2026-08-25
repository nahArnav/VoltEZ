"""CLI for reproducible, locked-test-safe demand evaluation."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from voltez_ml.evaluation.demand import DemandEvaluationSettings, evaluate_demand_model


def main() -> None:
    parser = argparse.ArgumentParser(description="Evaluate a VoltEZ demand artifact")
    parser.add_argument("--artifact-dir", type=Path, required=True)
    parser.add_argument("--feature-suite-manifest", type=Path)
    parser.add_argument("--output-root", type=Path, default=Path("reports/demand"))
    parser.add_argument("--include-train", action="store_true")
    parser.add_argument("--skip-stress", action="store_true")
    parser.add_argument("--permutation-sample-rows", type=int, default=50_000)
    parser.add_argument("--permutation-repeats", type=int, default=3)
    parser.add_argument("--random-seed", type=int, default=20260821)
    parser.add_argument(
        "--unlock-test",
        action="store_true",
        help="Evaluate the locked test world once; omit throughout development.",
    )
    args = parser.parse_args()
    artifact_dir = args.artifact_dir.resolve()
    artifact_manifest = json.loads((artifact_dir / "manifest.json").read_text("utf-8"))
    suite_path = args.feature_suite_manifest
    if suite_path is None:
        suite_path = artifact_dir / artifact_manifest["feature_suite_manifest"]
    output = evaluate_demand_model(
        artifact_dir,
        suite_path.resolve(),
        args.output_root.resolve(),
        DemandEvaluationSettings(
            include_train=args.include_train,
            include_stress=not args.skip_stress,
            unlock_test=args.unlock_test,
            permutation_sample_rows=args.permutation_sample_rows,
            permutation_repeats=args.permutation_repeats,
            random_seed=args.random_seed,
        ),
    )
    print(f"Evaluation report: {output}")
