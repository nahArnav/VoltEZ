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
- Synthetic generator v1.3: tolerance-aware availability truth plus independent worlds implemented
- Point-in-time feature view v3: target-aligned history, known context, purging, and leakage audits
- Multi-seed experiment readiness gate: implemented and passed on the final suite
- Five-world 90-day Pune dataset: generated and ready for all four model tracks
- Model 3/4 synthetic labels and leakage-safe feature views: implemented and smoke-tested
- Memory-safe five-world feature-suite builder: implemented
- Model 1 point-demand baseline: trained and published as a historical experiment
- Step 10B evaluator and causal 60-minute rolling-demand experiment: published
- Step 10C structural/world and context-feature correction: verified and published
- Step 13B detailed pre-test Poisson evaluation: complete
- Step 13C two-stage hurdle candidate: trained and evaluated as a challenger
- Model 1 champion: selected, robustness-audited, locked-test evaluated once, and bundled for APIs
- Model 1 deployment stage: synthetic-validated; real VoltEZ shadow monitoring is still required
- Model 2 data stage: 10-minute service-readiness label correction in progress

## Model 1: Demand Forecasting

The frozen champion predicts the expected number of charging requests in a Pune zone over a
60-minute window beginning 15 minutes after the prediction origin.

| Item | Final value |
|---|---|
| Bundle | [`voltez-demand-60m-pune-v1`](models/demand/voltez-demand-60m-pune-v1/) |
| Model ID | `demand-window-60m-hgbr-bdb1d74f9ce09d73` |
| Algorithm | Histogram gradient boosting with Poisson loss |
| Model SHA-256 | `82418d51b203e4a7b8e4e7fe94133700c393ddbd80564e59696855197fba5e29` |
| Training rows | 413,952 from two independent Pune worlds |
| Feature count | 52 causal, point-in-time features |
| Locked-test MAE | **0.739 requests** |
| Locked-test RMSE | **0.990 requests** |
| Within one request | **75.89%** |
| Top-demand non-zero precision | **85.10%** |
| Mean prediction / truth | **0.8983 / 0.8961** |
| Seasonal-baseline MAE improvement | **22.44%** |
| Serving robustness | 10,000 unseen validation/stress rows audited; 0% fallback |
| Deployment stage | `synthetic_validated` |

The repository stores the deployable model, its 52-feature contract, pre-test selection evidence,
robustness audit, and one-time locked-test report. Large generated Parquet training tables stay out
of Git; they are reproducible from the committed generator/configuration and their hashed manifests.
The serving layer rejects impossible inputs and schema drift, warns on mild distribution shift, and
uses a seasonal fallback when too many values fall outside training experience.

See the [complete model card](docs/model1_model_card.md) and
[FastAPI integration handoff](docs/model1_fastapi_integration.md).

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

After explicit training approval, train the directly comparable hurdle candidate:

```bash
uv run voltez-train-demand-hurdle-window \
  --feature-suite-manifest data/final/pune_v3/features/feature_suite_manifest.json \
  --window-minutes 60 \
  --forecast-lead-minutes 15
```

Build and audit an application-facing feature contract without accessing the locked test:

```bash
uv run voltez-build-demand-contract \
  --artifact-dir artifacts/demand_window_v3/<model-id> \
  --feature-suite-manifest data/final/pune_v3/features/feature_suite_manifest.json \
  --output reports/demand/v3/serving/feature_contract.json

uv run voltez-audit-demand-serving \
  --artifact-dir artifacts/demand_window_v3/<model-id> \
  --feature-contract reports/demand/v3/serving/feature_contract.json \
  --feature-suite-manifest data/final/pune_v3/features/feature_suite_manifest.json \
  --output reports/demand/v3/serving/robustness_audit.json
```

## Project structure

```text
configs/                 Versioned project and synthetic-data settings
docs/                    Architecture, data contracts, and explanations
src/voltez_ml/           Importable ML package
tests/                   Automated tests
data/                    Local generated data; ignored by Git
artifacts/               Local model artifacts; ignored by Git
models/                  Published immutable deployment bundles
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
See `docs/demand_hurdle.md` for the Step 13C hurdle formula, parameter effects, and safeguards.
See `docs/model1_model_card.md` for the frozen champion and honest real-world limitations.
See `docs/model1_fastapi_integration.md` for the backend serving and monitoring contract.
