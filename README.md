# VoltEZ

VoltEZ is an EV charging discovery, reservation, and decision-intelligence platform.

This branch (`ML-Arnav`) contains the ML foundation for:

1. Demand Forecasting
2. Charger Availability Prediction
3. Waiting-Time Prediction
4. Charger Reliability Prediction

## Current stage

- Application database blueprint: complete as a design document
- ML data contract: complete as a design document
- Python project foundation: installed, locked, and verified on Apple M4
- Schema v1.1 synthetic generator: implemented and verified on the small Pune profile
- Point-in-time feature builder: implemented with chronological purging and leakage audits
- Multi-seed experiment readiness gate: implemented and passed on the final suite
- Five-world 90-day Pune dataset: generated and ready for all four model tracks
- Model 3/4 synthetic labels and leakage-safe feature views: implemented and smoke-tested
- Memory-safe five-world feature-suite builder: implemented
- Model 1 point-demand baseline: trained, validated, and published with the test still locked
- Step 10B evaluator and causal 60-minute rolling-demand experiment: implemented locally

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

Check the canonical two-train/validation/test/stress plan without generating data:

```bash
uv run voltez-plan-data --profile pune_v1
```

Audit an approved five-world rehearsal without training:

```bash
uv run voltez-audit-rehearsal --rehearsal-root data/rehearsals/step_08
```

Build the canonical feature partitions sequentially after the five final source worlds exist:

```bash
uv run voltez-build-feature-suite \
  --source-root data/final/pune_v1/raw \
  --output-root data/final/pune_v1/features
```

Train Model 1 locally without unlocking the final test world:

```bash
uv run voltez-train-demand \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json
```

Train the causal 60-minute experiment, which sums four future 15-minute targets while retaining
only the feature vector available at the origin:

```bash
uv run voltez-train-demand-window \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json \
  --window-minutes 60 \
  --forecast-lead-minutes 15
```

Run the reusable evaluator on validation and stress without touching the locked test:

```bash
uv run voltez-evaluate-demand \
  --artifact-dir artifacts/demand/<model-id> \
  --include-train
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
See `docs/experiment_readiness.md` for Step 7 seeds, evaluation isolation, M4 safeguards, and
sponsor boundaries.
See `docs/README.md` for the ordered documentation map and `docs/rehearsal_results.md` for Step 8.
See `docs/model_training_handoff.md` for the final dataset, teammate handoff, and Model 1 commands.
See `docs/demand_evaluation.md` for Step 10B evaluation logic and the 60-minute experiment.
