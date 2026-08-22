"""CLI for the two-stage rolling-window demand hurdle candidate."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.training.demand_hurdle import (
    HurdleTrainingSettings,
    train_hurdle_demand_window_model,
)
from voltez_ml.training.demand_window import DemandWindowSettings


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Train a two-stage hurdle forecast for rolling VoltEZ demand"
    )
    parser.add_argument("--feature-suite-manifest", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, default=Path("artifacts/demand_hurdle"))
    parser.add_argument("--window-minutes", type=int, default=60)
    parser.add_argument("--forecast-lead-minutes", type=int, default=15)
    parser.add_argument("--bucket-minutes", type=int, default=15)
    parser.add_argument("--classifier-max-iter", type=int, default=250)
    parser.add_argument("--count-max-iter", type=int, default=250)
    parser.add_argument("--classifier-learning-rate", type=float, default=0.05)
    parser.add_argument("--count-learning-rate", type=float, default=0.05)
    parser.add_argument("--classifier-max-leaf-nodes", type=int, default=31)
    parser.add_argument("--count-max-leaf-nodes", type=int, default=31)
    parser.add_argument("--classifier-l2-regularization", type=float, default=0.2)
    parser.add_argument("--count-l2-regularization", type=float, default=0.2)
    parser.add_argument("--maximum-training-rows", type=int, default=1_500_000)
    parser.add_argument("--random-seed", type=int, default=20260821)
    parser.add_argument(
        "--unlock-test",
        action="store_true",
        help="Evaluate the locked test world once; omit throughout development.",
    )
    args = parser.parse_args()
    output = train_hurdle_demand_window_model(
        args.feature_suite_manifest.resolve(),
        args.output_root.resolve(),
        HurdleTrainingSettings(
            classifier_max_iter=args.classifier_max_iter,
            count_max_iter=args.count_max_iter,
            classifier_learning_rate=args.classifier_learning_rate,
            count_learning_rate=args.count_learning_rate,
            classifier_max_leaf_nodes=args.classifier_max_leaf_nodes,
            count_max_leaf_nodes=args.count_max_leaf_nodes,
            classifier_l2_regularization=args.classifier_l2_regularization,
            count_l2_regularization=args.count_l2_regularization,
            maximum_training_rows=args.maximum_training_rows,
            random_seed=args.random_seed,
        ),
        DemandWindowSettings(
            window_minutes=args.window_minutes,
            forecast_lead_minutes=args.forecast_lead_minutes,
            bucket_minutes=args.bucket_minutes,
        ),
        unlock_test=args.unlock_test,
    )
    print(f"Model artifact: {output}")
