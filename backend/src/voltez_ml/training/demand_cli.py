"""CLI for local Model 1 training."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.training.demand import DemandTrainingSettings, train_demand_model


def main() -> None:
    parser = argparse.ArgumentParser(description="Train VoltEZ Model 1 on a verified feature suite")
    parser.add_argument("--feature-suite-manifest", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, default=Path("artifacts/demand"))
    parser.add_argument("--max-iter", type=int, default=250)
    parser.add_argument("--learning-rate", type=float, default=0.05)
    parser.add_argument("--max-leaf-nodes", type=int, default=31)
    parser.add_argument("--l2-regularization", type=float, default=0.2)
    parser.add_argument("--maximum-training-rows", type=int, default=1_500_000)
    parser.add_argument("--random-seed", type=int, default=20260821)
    parser.add_argument(
        "--unlock-test",
        action="store_true",
        help="Evaluate the locked test world once; omit during model development.",
    )
    args = parser.parse_args()
    settings = DemandTrainingSettings(
        max_iter=args.max_iter,
        learning_rate=args.learning_rate,
        max_leaf_nodes=args.max_leaf_nodes,
        l2_regularization=args.l2_regularization,
        maximum_training_rows=args.maximum_training_rows,
        random_seed=args.random_seed,
    )
    output = train_demand_model(
        args.feature_suite_manifest.resolve(),
        args.output_root.resolve(),
        settings,
        unlock_test=args.unlock_test,
    )
    print(f"Model artifact: {output}")
