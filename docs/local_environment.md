# VoltEZ Local ML Environment Report

Verified on 2026-08-21 during Step 4.

## Machine and interpreter

| Item | Verified value |
| --- | --- |
| Chip | Apple M4 |
| CPU cores | 10: 4 performance and 6 efficiency |
| Memory | 16 GB |
| Architecture | arm64 |
| macOS | 26.6.2 |
| Environment manager | uv 0.12.5, native aarch64 build |
| Project Python | CPython 3.12.14, native arm64 build |

The repository uses uv's project-local `.venv`, so model code does not depend on the older Python
included with macOS or on the ordering of global shell paths.

## Locked foundation libraries

| Library | Version | Initial role |
| --- | --- | --- |
| NumPy | 2.5.2 | Numerical generation and deterministic random streams |
| Pandas | 2.3.3 | Inspection and scikit-learn interoperability |
| Polars | 1.43.2 | Memory-efficient event generation and aggregation |
| PyArrow | 25.0.1 | Typed Parquet datasets |
| Pydantic | 2.13.4 | Strict configuration and later API/data validation |
| PyYAML | 6.0.3 | Version-controlled human-readable configuration |
| scikit-learn | 1.9.0 | Baselines, preprocessing, calibration, and evaluation |

The full transitive dependency set is recorded in `uv.lock`.

## Acceleration decision

The first demand and availability models will use native Apple Silicon CPU execution. These are
tabular workloads, and the selected foundation libraries do not use PyTorch MPS. Configuration
therefore says `device: cpu` and permits automatic CPU thread selection. The working-memory budget
is 10 GB, leaving approximately 6 GB for macOS and other applications.

MPS is not reported as enabled because PyTorch is intentionally not installed at this stage. If a
later neural baseline is approved, PyTorch will be added separately and MPS availability and
numerical correctness will be tested rather than assumed.

## Validation results

| Check | Result |
| --- | --- |
| Configuration behavior tests | 8 passed |
| Ruff lint | Passed |
| Mypy strict type check | Passed for both source modules |
| Development configuration smoke load | Pune, 15-minute bucket, CPU, 10 GB budget |

The first executable run revealed that YAML parses an unquoted ISO date as a real date object. The
configuration model now uses `datetime.date` instead of pretending that value is arbitrary text.
This gives future generator code safe date arithmetic and rejects malformed dates earlier.

## Reproduce locally

```bash
uv sync --group dev
uv run pytest
uv run ruff check .
uv run mypy
```

No model training or synthetic data generation occurred during this environment-verification step.
