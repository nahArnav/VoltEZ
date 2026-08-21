"""Command-line entry point for local synthetic-data generation."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from pathlib import Path

from voltez_ml.config import load_config
from voltez_ml.synthetic.generator import generate_dataset


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a validated VoltEZ synthetic dataset; this command never trains models."
        )
    )
    parser.add_argument("--environment", choices=("development", "test"), default="development")
    parser.add_argument("--profile", default="pune_v1")
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--output-root", type=Path, default=None)
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(arguments)
    project_root = args.project_root.resolve()
    config = load_config(
        environment=args.environment,
        synthetic_profile=args.profile,
        project_root=project_root,
    )
    result = generate_dataset(config, project_root=project_root, output_root=args.output_root)
    print(
        json.dumps(
            {
                "run_id": result.run_id,
                "snapshot_id": result.snapshot_id,
                "output_dir": str(result.output_dir),
                "row_counts": result.row_counts,
                "reproducibility_fingerprint": result.reproducibility_fingerprint,
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
