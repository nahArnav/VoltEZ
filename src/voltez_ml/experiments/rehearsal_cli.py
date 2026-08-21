"""CLI for auditing completed rehearsal artifacts without model training."""

from __future__ import annotations

import argparse
import json
from collections.abc import Sequence
from pathlib import Path

from voltez_ml.experiments.rehearsal import write_rehearsal_audit


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Audit one five-seed rehearsal; this command never trains models."
    )
    parser.add_argument(
        "--rehearsal-root",
        type=Path,
        required=True,
        help="Directory containing synthetic/ and processed/ rehearsal artifacts.",
    )
    parser.add_argument("--output", type=Path, default=None)
    return parser


def main(arguments: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(arguments)
    destination, report = write_rehearsal_audit(
        args.rehearsal_root.resolve(),
        args.output.resolve() if args.output is not None else None,
    )
    print(
        json.dumps(
            {
                "status": report["status"],
                "report": str(destination),
                "failures": report["failures"],
                "warnings": report["warnings"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 2 if report["failures"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
