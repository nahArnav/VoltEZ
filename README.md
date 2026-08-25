# VoltEZ

VoltEZ is an EV charging discovery, reservation, and decision-intelligence platform.

This branch (`ML-Final`) contains the merged ML foundation for:

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
- Model 2 data stage: v1.3 correction and five-world Pune v4 feature suite complete
- Model 2 training stage: clean calibrated classifier and FastAPI-ready shadow bundle published;
  locked test remains closed
- Model 3 (Waiting Time) and Model 4 (Reliability): training, optional locked-test evaluation,
  serving predictors, contract builders, and automated tests implemented; no deployment bundles
  are committed yet
- Serving-contract builders and safe prediction layers exist for all four core models
- Supporting Model 5 Step 2: physics baseline plus schema-compatible vehicle energy profiles,
  immutable direct/candidate route snapshots, and long-route coverage implemented; no labels or
  training performed

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

## Model 2: Charger Availability Prediction

Model 2 estimates the calibrated probability that a specific charger port will be unavailable at
the driver's ETA. Deterministic backend eligibility gates run first; the model then returns one of
`available`, `unknown`, or `unavailable` so uncertain data is never silently treated as available.

| Item | Current value |
|---|---|
| Bundle | [`voltez-availability-pune-v1`](models/availability/voltez-availability-pune-v1/) |
| Model ID | `availability-hgb-calibrated-97315b1cdaf67db4` |
| Algorithm | Histogram gradient boosting + out-of-world Platt calibration |
| Model SHA-256 | `3813d8867eb9042c3931e63cae2e882d2b28311797f5e466a6d49b87fea35e82` |
| Training rows | 70,551 from two independent Pune worlds |
| Feature count | 35 causal, point-in-time features |
| Validation ROC-AUC / PR-AUC | **0.803 / 0.327** |
| Stress ROC-AUC / PR-AUC | **0.809 / 0.335** |
| Unsafe available rate | **4.95% validation / 4.77% stress** |
| Accuracy when a binary decision is made | **94.65% validation / 94.67% stress** |
| Locked test | Closed and never accessed |
| Deployment stage | `shadow` pending real traffic and final-test approval |

The bundle contains the clean model, hash-verified manifest, evaluation report, strict 35-feature
contract, and deployment metadata. Missing status, unseen categories, major distribution shift, or
mid-band probability produces `unknown` rather than an unsafe guess.

### Model 2 logic and verification

Model 2 treats `unavailable` as the positive class. Its most influential signals are the latest
port status, driver ETA, status age, active-session duration, connector type, reliability history,
nearby bookings, time of day, and time remaining before the host closes. It does not use entity IDs,
future session outcomes, final booking state, label metadata, or locked-test information.

The backend remains authoritative for hard facts. It first rejects incompatible connectors, closed
or unverified hosts, missing availability windows, known faults, and overlapping bookings. Only an
eligible candidate reaches the classifier. Histogram gradient boosting learns nonlinear
interactions between the 35 point-in-time features; Platt calibration then converts its raw score
into an estimated probability of unavailability.

Two thresholds turn that probability into a safe application decision:

| Probability of unavailability | API decision | Meaning |
|---|---|---|
| `<= 0.1674` | `available` | Validation risk of being wrong is at most the selected 5% target |
| `0.1674 - 0.4385` | `unknown` | Evidence is not strong enough for either binary claim |
| `>= 0.4385` | `unavailable` | Selected validation precision is at least the 60% target |

Verification used 35,276 rows from an independent validation world and 37,452 rows from a separate
stress world. Model 2 beat the always-available, prevalence, fresh-status, and logistic-regression
baselines; achieved ROC-AUC `0.803/0.809` and PR-AUC `0.327/0.335`; kept calibration error below
`0.007`; and passed all seven frozen development gates. The published artifact records clean commit
`7ad207a`, verifies its SHA-256 before loading, and was exercised through the same Pydantic predictor
used by FastAPI. The test suite covers schema drift, timestamp consistency, batch consistency,
unknown status, unseen category, and abstention behavior.

This is development and serving verification, not proof from live traffic. Roughly 31% of
validation/stress cases become `unknown`, and explicit `unavailable` recall is about 4.2% because
the current policy favors precision and user safety. The locked test remains unopened, and the
bundle must run in shadow mode on real VoltEZ events before production promotion.

## Supporting Model 5: Route-Energy Prediction

Steps 1 and 2 contain no trained ML artifact. Step 1 defines an auditable force/energy baseline,
conservative reachability policy, leakage rules, and evaluation gates. Step 2 adds one versioned
public energy profile per vehicle, immutable destination and candidate-charger route snapshots, and
geographically consistent urban/highway/intercity coverage trips. The planned model predicts
residual error around physics rather than relearning basic physical laws.

```python
from voltez_ml.route_energy import (
    RoutePhysicsInput,
    VehiclePhysicsInput,
    assess_reachability,
    estimate_physics_energy,
)
```

The physics fallback accounts for rolling resistance, aerodynamic drag, climbing, stop-start
losses, auxiliary load, drivetrain efficiency, and bounded downhill regeneration. Reachability uses
conservative P90 energy and the driver's reserve SOC; expected energy alone is not treated as a
safety guarantee.

See [the complete Step 1 design](docs/model5_route_energy_design.md) and the machine-readable
contract at [`configs/model_specs/route_energy_v1.yaml`](configs/model_specs/route_energy_v1.yaml).
See the [Step 2 implementation guide](docs/model5_route_energy_step2.md) for table relationships,
parameter logic, synthetic coverage, commands, and the explicit boundary before hidden truth.

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

Train Model 2 with two-world calibration, validation thresholds, and stress evaluation without
opening the locked test:

```bash
uv run voltez-train-availability \
  --feature-suite-manifest data/final/pune_v4/features/feature_suite_manifest.json \
  --output-root artifacts/availability
```

Build Model 2's backend feature contract from training worlds only:

```bash
uv run voltez-build-availability-contract \
  --artifact-dir artifacts/availability/<model-id> \
  --feature-suite-manifest data/final/pune_v4/features/feature_suite_manifest.json \
  --output artifacts/availability/<model-id>/feature_contract.json
```

Train Model 3 (Waiting Time) and Model 4 (Reliability) hurdle and calibrated models on the dataset:

```bash
uv run voltez-train-waiting-time \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json \
  --output-root artifacts/waiting_time \
  --unlock-test

uv run voltez-train-reliability \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json \
  --output-root artifacts/reliability \
  --unlock-test
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
See `docs/model2_availability_training.md` for Model 2 logic, calibration, metrics, and parameters.
See `docs/backend_fastapi_handoff.md` for the current Backend-branch FastAPI integration contract.
See the [Models 1 and 2 logical analysis PDF](output/pdf/VoltEZ_Models_1_and_2_Logical_Analysis.pdf)
for a visual, builder-friendly explanation of both models, their data, evaluation, integration,
monitoring, and limitations.
