"""CLI for sequential final feature-suite assembly."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from voltez_ml.config import load_config
from voltez_ml.features.suite import build_feature_suite


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Build and audit the canonical feature suite one world at a time"
    )
    parser.add_argument("--source-root", type=Path, required=True)
    parser.add_argument("--output-root", type=Path, required=True)
    parser.add_argument("--environment", choices=("development", "test"), default="development")
    parser.add_argument("--profile", default="pune_v1")
    args = parser.parse_args()
    project_root = Path.cwd()
    config = load_config(args.environment, args.profile, project_root)
    result = build_feature_suite(
        config,
        project_root,
        args.source_root.resolve(),
        args.output_root.resolve(),
    )
    readiness = json.loads(result.readiness_path.read_text("utf-8"))
    print(
        json.dumps(
            {
                "manifest": str(result.manifest_path),
                "readiness": str(result.readiness_path),
                "status": readiness["status"],
                "feature_datasets": len(result.feature_datasets),
            },
            indent=2,
            sort_keys=True,
        )
    )
