# Step 9 — Final dataset and Model 1 training handoff

## The short answer

The same **raw synthetic Pune worlds** support all four models, but the models must not train on
one universal CSV. Each question has a different prediction target, evidence cutoff, supervised
subset, feature table, metric, and training script.

| Model | Question | Supervised table | Target |
|---|---|---|---|
| 1 — Demand | How many charging requests will this zone receive? | `demand_features` | `target_request_count` |
| 2 — Availability | Will this physical port be usable at ETA? | `availability_features_labeled` | available / unavailable |
| 3 — Waiting time | How long until the reserved port is service-ready? | `waiting_time_features_labeled` | `label_wait_minutes` |
| 4 — Reliability | Will the charger itself complete service? | `reliability_features_labeled` | reliable / unreliable |

Unknown outcomes remain in each `*_all` table for coverage and censoring analysis. They never enter
ordinary supervised training as false labels.

## Is the current two-day dataset enough?

No. It is a software rehearsal that proves IDs, timestamps, joins, roles, hashes, and leakage rules.
It is not a training dataset. Two days cannot teach weekly cycles, mature reliability history, or
enough rare failures and queues.

The final profile is intentionally larger:

- 90 days per world;
- 24 named Pune zones;
- 180 charging hosts;
- 240 chargers with one to three ports;
- 6,000 anonymized synthetic drivers;
- two independent training worlds;
- one validation world;
- one locked test world;
- one harder stress world;
- weekday, weekend-retail, event, monsoon, outage-cluster, and stale-report scenarios.

This is sufficient for a hackathon-quality **Pune synthetic MVP** if every readiness gate passes.
It is not evidence that the model generalizes to Mumbai, Delhi, or real production traffic. Real
requests, sessions, status events, weather, and event data must later recalibrate it.

## Why the final data is diverse without becoming random nonsense

The generator uses causal layers:

1. Stable city entities are created first.
2. Each zone receives its own hidden demand tendency.
3. Time-of-day, day-of-week, neighboring zones, and scenario effects alter request intensity.
4. Requests generate candidates before selections, bookings, sessions, and outcomes.
5. Database booking overlaps remain forbidden.
6. Actual session duration may overrun a reservation and create a real queue for the next driver.
7. Each port has hidden health that affects outage frequency and repair duration.
8. Owner/user reports can be stale or wrong, so the model must learn evidence quality.
9. Hidden demand and port health remain in `qa_latent_*` tables and are forbidden as features.

This creates learnable relationships while preserving realistic uncertainty. Synthetic data can be
logically consistent; it cannot be called empirically accurate until compared with real operations.

## Model 3 logic

The target is queue time from verified check-in until the booked port becomes service-ready. Plug-in
and cable setup are not called a queue. A charger fault is not called a queue either.

Confirmed database reservations still never overlap. Positive waits arise when a previous real
session overruns its reserved end. If the wait exceeds the configured driver tolerance, the driver
may abandon, but the prior session checkout can still provide a known time-to-free label.

Most waits should be zero in a reservation system. Model 3 should therefore be a hurdle model:

1. classifier: probability that wait is greater than zero;
2. regressor: minutes of wait conditional on a positive queue;
3. final expectation: `P(wait > 0) × predicted_positive_minutes`.

Readiness requires positive queue examples in train, validation, and locked test worlds. A low MAE
from always predicting zero is not acceptable.

## Model 4 logic

Reliability isolates charger hardware/service trust from availability:

- completed session → `reliable`;
- verified charger fault before or during charging → `unreliable`;
- prior-session overrun/congestion → `unknown`, because it does not prove broken hardware;
- driver cancellation or no-show → no reliability accusation.

The model sees only evidence available at request time: earlier completed/failed sessions, smoothed
reliability, status freshness/source/confidence, charger type, power, and site context. It never sees
the hidden port-health probability that generated the fault.

## Why the feature suite is partitioned

The conservative plan estimates about 3.47 million raw rows per 90-day world. Combining the four
ordinary worlds before feature construction could exceed 26 GB, above the project's 10 GB working
budget on a 16 GB M4.

`voltez-build-feature-suite` therefore loads and materializes one world at a time. The result is a
portable directory:

```text
data/final/pune_v1/
├── raw/
│   ├── sim-.../              train world 1
│   ├── sim-.../              train world 2
│   ├── sim-.../              validation world
│   ├── sim-.../              locked test world
│   └── sim-.../              stress world
└── features/
    ├── features-.../         one partition per source world
    ├── feature_suite_manifest.json
    └── training_readiness.json
```

Paths in the suite manifest are relative. Copying the whole `pune_v1` directory to a teammate's
machine does not preserve or expose the original macOS username.

## Final data generation commands

Run these only from a clean committed `ML-Arnav` worktree. The generator refuses to call a dirty
five-world collection final.

```bash
uv sync --group dev
uv run voltez-plan-data --profile pune_v1
mkdir -p data/final/pune_v1/raw
```

Generate sequentially, not in parallel:

```bash
uv run voltez-generate --environment development --profile pune_v1 \
  --experiment train_seed_01 --output-root data/final/pune_v1/raw

uv run voltez-generate --environment development --profile pune_v1 \
  --experiment train_seed_02 --output-root data/final/pune_v1/raw

uv run voltez-generate --environment development --profile pune_v1 \
  --experiment validation_seed_01 --output-root data/final/pune_v1/raw

uv run voltez-generate --environment development --profile pune_v1 \
  --experiment test_seed_01 --output-root data/final/pune_v1/raw

uv run voltez-generate --environment development --profile pune_v1 \
  --experiment stress_seed_01 --output-root data/final/pune_v1/raw
```

Build all four model views one world at a time:

```bash
uv run voltez-build-feature-suite \
  --environment development \
  --profile pune_v1 \
  --source-root data/final/pune_v1/raw \
  --output-root data/final/pune_v1/features
```

Open `data/final/pune_v1/features/training_readiness.json`. Do not train a model whose individual
status is `not_ready`. The stress world is deliberately harder and does not decide the headline
readiness gate.

## Start Model 1 training

### 1. Verify the environment

```bash
uv sync --group dev
uv run pytest
uv run python -c "import platform; print(platform.machine())"
```

The machine should report `arm64`.

### 2. Run a short pipeline check

```bash
uv run voltez-train-demand \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json \
  --max-iter 50 \
  --maximum-training-rows 300000
```

This checks loading, fitting, validation, metrics, and artifact writing. It does not unlock the test
world.

### 3. Run the main first experiment

```bash
uv run voltez-train-demand \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json \
  --max-iter 250 \
  --learning-rate 0.05 \
  --max-leaf-nodes 31 \
  --l2-regularization 0.2 \
  --maximum-training-rows 1500000
```

The script fits only the two `train` worlds and reports metrics on the independent `validation`
world. It saves a model, evaluation report, artifact hashes, exact feature list, and parameters under
`artifacts/demand/`.

### 4. Understand the parameters

| Parameter | What increasing it does | Main risk |
|---|---|---|
| `max-iter` | adds more boosting stages | slower training and eventual overfit |
| `learning-rate` | lets each stage correct more strongly | unstable/overfit model if too high |
| `max-leaf-nodes` | learns more detailed nonlinear rules | memorizes synthetic quirks |
| `l2-regularization` | shrinks extreme leaf predictions | too much causes underfitting |
| `maximum-training-rows` | exposes more training examples | higher RAM and training time |

Change one family of parameters at a time and choose using validation only.

### 5. Read the metrics

- MAE: average absolute request-count error; primary plain-language metric.
- RMSE: penalizes large misses more strongly.
- WAPE: total absolute error divided by total observed demand.
- Mean Poisson deviance: count-aware metric used for skewed non-negative demand.
- Nonzero MAE: prevents zero-heavy buckets from hiding poor busy-period predictions.

The trained model must be compared with `seasonal_naive`, which uses last week, then yesterday, then
the recent exponentially weighted mean. A complex model that cannot beat this baseline is rejected.

### 6. Keep the test world locked

Do not pass `--unlock-test` while choosing features or parameters. After one final configuration is
frozen, run it once with that flag and record the result. Repeatedly looking at test performance turns
the test world into another validation set.

## Apple M4 hardware logic

Model 1 uses scikit-learn histogram gradient boosting. That library trains this estimator on CPU and
does not use Apple MPS. The M4 CPU is the correct hardware path; claiming GPU acceleration here
would be misleading. Histogram binning is already memory-efficient and multithreaded by the wheel.

If the Mac becomes memory pressured, reduce `maximum-training-rows` to 750,000 before reducing model
quality parameters. Close memory-heavy applications during the final run. A later PyTorch sequence
model can use `torch.device("mps")`, but it should only be attempted after this count-aware tabular
baseline is proven.

## Suggested teammate split

| You | ML teammate |
|---|---|
| Run and explain Model 1 demand experiments | Build Model 3 hurdle classifier/regressor |
| Own Model 2 availability after Model 1 | Build Model 4 calibrated reliability classifier |
| Protect the locked test-world policy | Share common evaluation and artifact conventions |
| Integrate Model 1/2 outputs with FastAPI | Deliver Model 3/4 inference functions to the same contract |

Both people use `feature_suite_manifest.json`; neither manually reshuffles or relabels rows.

## Sponsor usage boundary

No sponsor credential is required to train the first synthetic baseline. This is deliberate.

- Google Maps can later provide real ETA, route, and traffic features.
- Tavily can later ingest timestamped public event context.
- Swytchcode can govern those external API executions.
- CodeMate AI can review leakage tests and feature contracts now.
- n8n can orchestrate sequential generation/retraining after credentials arrive.
- Render can host the FastAPI inference service and scheduled jobs.
- Gemini/Lyzr can explain numeric outputs; they must not invent forecasts or labels.

Sponsor adapters must record source and ingestion time and degrade gracefully when unavailable. Their
absence must not change synthetic truth or silently alter the locked evaluation worlds.

## Knowledge check

1. Why can all four models share raw worlds but not one feature CSV?
2. Why is a previous-session overrun `unknown` rather than `unreliable` for Model 4?
3. Why can always predicting zero produce a misleading Model 3 MAE?
4. What makes `request_lag_same_time_last_week` safe at prediction time?
5. Why should `--unlock-test` be used only once after the final configuration is frozen?
