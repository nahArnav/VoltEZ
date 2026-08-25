"""CLI for locked-test-safe Model 2 training."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.training.availability import (
    AvailabilityTrainingSettings,
    train_availability_model,
)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train calibrated VoltEZ charger availability Model 2 without test access"
    )
    parser.add_argument("--unlock-test", action="store_true")
    parser.add_argument("--feature-suite-manifest", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, default=Path("artifacts/availability"))
    parser.add_argument("--max-iter", type=int, default=250)
    parser.add_argument("--learning-rate", type=float, default=0.05)
    parser.add_argument("--max-leaf-nodes", type=int, default=31)
    parser.add_argument("--min-samples-leaf", type=int, default=30)
    parser.add_argument("--l2-regularization", type=float, default=0.5)
    parser.add_argument("--target-available-risk", type=float, default=0.05)
    parser.add_argument("--target-unavailable-precision", type=float, default=0.60)
    parser.add_argument("--minimum-threshold-rows", type=int, default=100)
    parser.add_argument("--permutation-sample-rows", type=int, default=10_000)
    parser.add_argument("--permutation-repeats", type=int, default=3)
    parser.add_argument("--random-seed", type=int, default=20260822)
    args = parser.parse_args()
    settings = AvailabilityTrainingSettings(
        max_iter=args.max_iter,
        learning_rate=args.learning_rate,
        max_leaf_nodes=args.max_leaf_nodes,
        min_samples_leaf=args.min_samples_leaf,
        l2_regularization=args.l2_regularization,
        target_available_risk=args.target_available_risk,
        target_unavailable_precision=args.target_unavailable_precision,
        minimum_threshold_rows=args.minimum_threshold_rows,
        permutation_sample_rows=args.permutation_sample_rows,
        permutation_repeats=args.permutation_repeats,
        random_seed=args.random_seed,
    )
    output = train_availability_model(
        args.feature_suite_manifest.resolve(),
        args.output_root.resolve(),
        settings,
        unlock_test=args.unlock_test,
    )
    print(f"Model artifact: {output}")


if __name__ == "__main__":
    main()
