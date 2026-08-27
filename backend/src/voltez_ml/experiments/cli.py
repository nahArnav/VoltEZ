"""CLI for the no-write, no-training multi-seed readiness check."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from pathlib import Path

from voltez_ml.experiments.readiness import (
    DEFAULT_EXPERIMENT_PROFILES,
    build_data_readiness_report,
)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Validate the VoltEZ multi-seed plan without generating data or training."
    )
    parser.add_argument("--environment", choices=("development", "test"), default="development")
    parser.add_argument("--profile", default="pune_v1")
    parser.add_argument(
        "--experiment",
        action="append",
        dest="experiments",
        help="Repeat to supply a custom experiment set; canonical five-run plan is the default.",
    )
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(arguments)
    profiles = tuple(args.experiments or DEFAULT_EXPERIMENT_PROFILES)
    report = build_data_readiness_report(
        project_root=args.project_root.resolve(),
        synthetic_profile=args.profile,
        experiment_profiles=profiles,
        environment=args.environment,
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 2 if report["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
