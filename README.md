# VoltEZ

VoltEZ is an EV charging discovery, reservation, and decision-intelligence platform.

This branch (`ML-Arnav`) contains the ML foundation for:

1. Demand Forecasting
2. Charger Availability Prediction

## Current stage

- Application database blueprint: complete as a design document
- ML data contract: complete as a design document
- Python project foundation: installed, locked, and verified on Apple M4
- Schema v1.1 synthetic generator: implemented and verified on the small Pune profile
- Point-in-time feature builder: implemented with chronological purging and leakage audits
- Model training: not implemented yet

## Local environment

The project uses Python 3.12 and `uv` for a reproducible local environment.

```bash
uv sync --group dev
uv run pytest
```

These commands install dependencies and run tests. Do not run training until the generator,
data validation, and chronological split logic have been reviewed.

Generate the small review dataset:

```bash
uv run voltez-generate --environment test --profile pune_test
```

Build features from an approved run:

```bash
uv run voltez-build-features \
  --environment test \
  --profile pune_test \
  --input-run data/synthetic/<run-id>
```

## Project structure

```text
configs/                 Versioned project and synthetic-data settings
docs/                    Architecture, data contracts, and explanations
src/voltez_ml/           Importable ML package
tests/                   Automated tests
data/                    Local generated data; ignored by Git
artifacts/               Local model artifacts; ignored by Git
reports/                 Local generated reports; ignored by Git
```

See `docs/project_foundation.md` for the purpose and logic of each foundation file.
See `docs/local_environment.md` for the verified Apple M4 environment and validation results.
See `docs/synthetic_generator.md` for every Step 5 rule, parameter effect, and knowledge check.
See `docs/schema_reconciliation_v1_1.md` for the revised backend-to-ML schema mapping.
See `docs/feature_engineering.md` for every Step 6 leakage rule, feature, split, and audit.
