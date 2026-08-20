# VoltEZ ML Project Foundation Explained

This document explains every file introduced during Step 3. No generator or model-training logic
exists yet.

## 1. Toolchain choice

### Python 3.12

The project pins Python 3.12 because it provides modern language features while retaining broad
compatibility across the scientific Python libraries we need. The pin prevents one teammate from
using a different interpreter and producing environment-specific behavior.

### uv

`uv` manages Python, the virtual environment, dependencies, and the lockfile. Dependencies are
declared in `pyproject.toml`, and a future `uv.lock` will record the exact versions installed on the
team's machines.

`uv.lock` was created during approved Step 4. It records the exact resolved dependency versions so
both teammates can recreate the verified environment rather than receiving whichever package
versions happen to be newest on installation day.

## 2. Apple M4 acceleration decision

The first two models are tabular tree-based models, so the M4 CPU is the appropriate primary
processor:

- configuration uses `device: cpu`;
- `thread_count: -1` means a supporting library may use all available CPU cores;
- `memory_budget_gb: 10` leaves approximately 6 GB for macOS and other applications;
- the generator receives a hard maximum-row safeguard;
- vectorized NumPy, Polars, Pandas, PyArrow, and scikit-learn operations avoid slow Python loops.

Apple Metal/MPS is real GPU acceleration for compatible PyTorch workloads. It does not make
scikit-learn, XGBoost, or CatBoost automatically use the Apple GPU. XGBoost's documented macOS
Apple Silicon distribution does not provide GPU support, while CatBoost's documented GPU build
path is CUDA/NVIDIA-oriented. We will therefore use measured CPU parallelism rather than a fake
GPU switch. If a later neural experiment is justified, PyTorch MPS will be evaluated separately.

## 3. `pyproject.toml`

This is the authoritative project metadata and dependency file.

### Runtime dependencies

- `numpy`: numerical arrays and random-number foundations.
- `pandas`: familiar tabular inspection and compatibility with ML libraries.
- `polars`: fast, memory-efficient generation and aggregation.
- `pyarrow`: Parquet storage and typed column interchange.
- `scikit-learn`: baselines, preprocessing, validation, calibration, and initial tree models.
- `joblib`: versioned model serialization and controlled parallel helpers.
- `pydantic`: validates configuration and later API/data contracts.
- `pyyaml`: reads human-editable configuration files.

CatBoost, LightGBM, XGBoost, PyTorch, MLflow, FastAPI, database clients, and sponsor SDKs are not
added yet. Each should be introduced when its role is approved and tested.

### Development dependencies

- `pytest`: automated tests.
- `pytest-cov`: shows which important logic is untested.
- `ruff`: formatting-independent code quality, import ordering, and common bug detection.
- `mypy`: static type checking.

## 4. `.python-version`

Tells `uv` and compatible tools to use Python 3.12 for this checkout.

## 5. `.gitignore`

Keeps local environments, caches, secrets, large generated datasets, reports, and trained model
artifacts out of Git. Configuration, source code, tests, documentation, and future lockfiles remain
version controlled.

## 6. `.env.example`

Documents the names of future infrastructure and sponsor settings without containing real secrets.
The real `.env` file is ignored. API keys must never be pasted into source code, notebooks, model
artifacts, logs, or chat messages.

## 7. Layered configuration

The loader merges three files in this order:

1. `configs/base.yaml`
2. `configs/environments/{environment}.yaml`
3. `configs/synthetic/{profile}.yaml`

Later files override only the keys they explicitly contain. This prevents duplication while making
test settings small and deterministic.

### Important base parameters

| Parameter | Meaning | Effect of increasing it |
| --- | --- | --- |
| `seed` | Starting state for repeatable random generation | Changing it creates a different dataset; the same value must reproduce the same run |
| `thread_count` | CPU worker/thread request | More may improve speed until memory bandwidth or overhead becomes limiting |
| `memory_budget_gb` | Maximum intended working memory | Larger batches become possible, but macOS may swap or terminate processes if set too high |
| `bucket_minutes` | Demand aggregation interval | Larger buckets are less sparse but reduce time precision |
| `demand_horizons_minutes` | Future distances predicted by Model 1 | Longer horizons are useful for planning but usually harder to predict |
| `availability_eta_buckets_minutes` | Arrival horizons evaluated by Model 2 | More horizons improve coverage but increase dataset and evaluation complexity |

### Initial synthetic-profile parameters

| Parameter | Meaning | Effect of increasing it |
| --- | --- | --- |
| `days` | Length of generated history | More seasonal examples, larger files, and longer generation/training |
| `zone_count` | Pune spatial cells represented | More geographic detail, but more sparsity per zone |
| `business_count` | Host sites | More supply diversity and relationships |
| `charger_count` | Physical charger units | More supply and availability combinations |
| `driver_count` | Simulated driver population | More behavior diversity and memory use |
| `average_requests_per_zone_per_day` | Mean demand intensity | More request events and usually more bookings/queues |
| `negative_binomial_dispersion` | Controls count variance around mean under the chosen parameterization | Its exact effect will be locked and tested when the generator formula is implemented |
| `spatial_spillover_weight` | Neighboring-zone demand influence | Stronger geographic correlation and wider event effects |
| `base_operational_probability` | Prior chance a port is technically operational | Higher values create fewer technical-unavailability labels |
| report error probabilities | Chance a reported state disagrees with truth | Higher values make status freshness/source features more important |
| `median_status_ttl_minutes` | Typical lifetime of a status report | Higher values keep reports active longer and risk more stale information |
| `maximum_generated_rows` | Safety ceiling | Higher values permit larger runs but increase memory and disk risk |

The dispersion parameter is deliberately not over-explained yet because libraries use different
Negative Binomial parameterizations. We will define one formula, test its mean and variance, and
then explain its direction precisely before generator code is approved.

## 8. `src/voltez_ml/config.py`

### Strict models

`extra="forbid"` rejects misspelled keys. Without this, `bucket_minute: 15` could be silently
ignored while the program uses an unintended default.

### Field bounds

Pydantic bounds reject impossible values before work starts. Probabilities remain between 0 and 1,
counts are positive, and the M4 memory budget cannot exceed 12 GB in this configuration.

### Time-grid validation

The bucket must divide evenly into one hour. Every demand horizon must be a positive, sorted,
unique multiple of that bucket. This ensures targets line up with actual rows instead of producing
partial or ambiguous buckets.

### Scenario validation

Scenario probabilities must sum to exactly 1 within numerical tolerance. Negative probabilities
are rejected. The initial profile also requires at least one charger per business on average.

### Deep merge

`_deep_merge` recursively combines nested mappings and deep-copies values. It does not mutate the
input dictionaries, making repeated tests and configuration comparisons predictable.

### Config loading

`load_config` resolves the project root, reads the three YAML layers, merges them, and performs one
final typed validation. Future scripts will accept the validated object instead of reading random
environment variables or global constants throughout the codebase.

## 9. `tests/test_config.py`

The tests verify:

- expected Pune, timezone, bucket, horizon, and CPU defaults;
- the test environment overrides only intended values;
- merging does not mutate its inputs;
- invalid scenario probabilities are rejected;
- misaligned forecast horizons are rejected;
- an unsafe M4 memory budget is rejected.

These are behavior tests, not tests that merely duplicate implementation lines.

## 10. What comes next

Step 4 installed and locked the environment, ran lint/type/test checks, and recorded the actual
Apple M4 environment report. The next approved step can begin the synthetic generator in small,
independently tested modules. It should start with deterministic simulation identity, Pune zones,
and static supply entities before generating demand or availability outcomes.
