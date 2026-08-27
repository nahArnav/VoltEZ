"""Command-line entry point for point-in-time feature generation."""

from __future__ import annotations

import argparse
from pathlib import Path

from voltez_ml.config import load_config
from voltez_ml.features.builder import build_feature_dataset


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build audited VoltEZ ML feature tables")
    parser.add_argument(
        "--input-run",
        action="append",
        required=True,
        type=Path,
        help="Synthetic run directory; repeat for cross-seed feature building",
    )
    parser.add_argument("--environment", choices=("development", "test"), default="development")
    parser.add_argument("--profile", default="pune_v1")
    parser.add_argument("--output-root", type=Path)
    return parser


def main() -> None:
    args = _parser().parse_args()
    project_root = Path.cwd()
    config = load_config(args.environment, args.profile, project_root)
    result = build_feature_dataset(
        config,
        project_root,
        [path.resolve() for path in args.input_run],
        args.output_root.resolve() if args.output_root else None,
    )
    print(f"Feature snapshot: {result.feature_snapshot_id}")
    print(f"Output: {result.output_dir}")
    print(f"Rows: {result.row_counts}")


if __name__ == "__main__":
    main()
