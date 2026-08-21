# VoltEZ Step 6 — Point-in-time feature engineering

Status: v3 implemented locally; Step 10C source awaits approval to commit
Models: Demand Forecasting and Charger Availability Prediction
Schema input: v1.1

## 1. Plain-language purpose

A feature is a fact the model may use. A label is the future answer it is trying to learn.
Step 6 converts raw simulator events into rows that strictly separate those two things.

For every row, the builder asks:

> If VoltEZ had made this prediction at this exact time, what information had actually reached
> the application by then?

This prevents **data leakage**: accidentally teaching the model with information from the future.
A leaked model can look spectacular during testing and then fail in the real application.

## 2. Output files

Each feature snapshot contains:

| File | Meaning |
| --- | --- |
| `demand_features.parquet` | Zone/origin/target/horizon rows for Model 1 |
| `availability_features_all.parquet` | Every candidate observation, including unknown outcomes |
| `availability_features_labeled.parquet` | Only available/unavailable rows permitted for supervised Model 2 fitting |
| `audit_report.json` | Leakage, split, missingness, class balance, and distribution results |
| `manifest.json` | Source-run hashes, feature-code hash, versions, row counts, and output hashes |

Unknown availability rows remain available for coverage and censoring analysis. They are not
silently changed to unavailable and are not copied into the supervised table.

## 3. Demand model row

One row means:

`zone × prediction_origin × target_time × forecast_horizon`

If the prediction origin is 10:00 and the horizon is 60 minutes, the label is the request count in
the 11:00–11:15 bucket. The 10:00–10:15 bucket is not yet complete at 10:00, so it cannot be an
input.

### The critical shift-first rule

The code first calculates:

`request_lag_1 = request_count shifted backward by one complete bucket`

Only then does it calculate rolling sums, means, standard deviation, and exponentially weighted
history. This order matters. Rolling first and shifting later is easy to get wrong and can include
part of the current bucket.

### Model 1 feature groups

- previous complete-bucket request, search, unserved, booking, session, supply, and occupancy data;
- request sums over the configured previous 15, 30, 60, and 360 minutes;
- rolling mean, standard deviation, and exponentially weighted demand;
- same time yesterday and last week, with explicit missing flags;
- target-slot-aligned yesterday and last-week demand, so a 60-minute-ahead forecast compares the
  exact future clock slot rather than the origin's clock slot;
- previous-hour no-candidate rate;
- previous demand from the two geographically nearest Pune zone centroids;
- target hour/day encoded cyclically, weekend flag, horizon, and zone centroid;
- numeric one-hot zone-type features from public application metadata;
- scheduled event type/count/impact when the event covers the target and its publication and
  ingestion timestamps are both at or before the prediction origin.

The current bucket's `request_count` and all target-bucket facts are removed from the feature
output. `target_request_count` is the only future count.

### The keyed target rule

Future demand is joined by `simulation_run_id`, `zone_id`, and `target_time`. It is never assigned
by DataFrame row position, because a merge may legally reorder rows. The test suite compares every
feature label against its exact raw future bucket so one zone cannot inherit another zone's count.

## 4. Availability model row

One row means:

`request × candidate port × prediction_origin × target arrival`

The row contains only state known at the origin:

- bookings whose confirmation occurred by the origin and whose cancellation was not already
  known;
- active-session state as of the origin and elapsed time, never the realized remaining duration;
- past completed/failed session evidence in the configured history window;
- the latest status report whose **ingestion time** is at or before the origin;
- whether that report is expired, its age, source, and source confidence;
- demand buckets that had fully ended before the origin;
- static connector, charging type, power, site size, host category/access, and schedule facts;
- target-time calendar and ETA features.

`booking_state` and `port_status` from `analytics.availability_observations` describe what was found
at the target time. They are label context and are deliberately absent from the feature columns.

### Bayesian reliability

The smoothed reliability feature is:

`(past successes + prior successes) / (past evidence + prior successes + prior failures)`

The default prior is 2 successes and 2 failures, so a new port begins at 0.5 rather than 0 or 1.
As genuine evidence accumulates, the history gradually outweighs the prior. This avoids extreme
confidence from one lucky session and marks low-evidence ports as cold starts.

The application column `chargers.reliability_score` is not used because it may be stale,
calculated with future history, or produced by another model.

## 5. Split logic

Headline evaluation is never a random row split.

For each simulation run, unique prediction origins are divided chronologically into approximately
70% train, 15% validation, and 15% test. A row near a boundary is dropped when its future target
crosses that boundary. Therefore:

- every training target occurs before validation begins;
- every validation target occurs before test begins;
- no long-horizon label reaches into the next split.

An additional `run_holdout_split` column comes only from each source manifest's explicit
experiment role. Directory names and sort order never assign evaluation roles. A canonical build
requires independent `train`, `validation`, and `test` worlds; an optional `stress_test` world is
kept outside headline metrics. Development-role runs are reported as unavailable for cross-seed
claims and cannot be mixed with explicitly assigned runs.

## 6. Audits

The build fails for:

- a feature cutoff or source time after the prediction origin;
- a target at or before its prediction origin;
- duplicated feature keys;
- latent QA columns in model output;
- negative demand labels;
- invalid availability label states;
- unknown labels in the supervised availability table;
- feature-source timestamps after the origin;
- train/validation/test target overlap;
- a numerical demand feature exactly equal to its future label.

The report warns for:

- missing cross-seed evaluation;
- a one-class or severely imbalanced availability label set;
- missing and constant columns that require review.

Automated mutation tests deliberately change future demand, add a delayed status event, and add a
context event ingested after the origin. They prove that features at the earlier origin do not
change even though future labels or later-known context may change. A separate exact-slot test
verifies every target-aligned yesterday value against its raw historical bucket.

## 7. Configuration effects

| Setting | Effect when increased | Trade-off |
| --- | --- | --- |
| `demand_recent_windows_buckets` | Adds longer/extra rolling demand memories | More correlated features and larger search space |
| `demand_ewm_span_buckets` | Makes recent spikes decay more slowly | May react too slowly to sudden change |
| `demand_minimum_history_buckets` | Removes more early cold-history rows | Cleaner history but fewer training rows |
| `availability_history_hours` | Uses more past reliability evidence | Older behavior may be less relevant |
| reliability prior successes/failures | Makes the prior harder for little data to move | More stable cold starts but slower personalization |
| `cold_start_evidence_threshold` | Marks more ports as cold starts | Safer confidence handling but fewer “established” ports |
| temporal split fractions | Changes history available to each stage | Very small validation/test windows give unstable metrics |

## 8. Commands

After generating and reviewing a source run:

```bash
uv run voltez-build-features \
  --environment test \
  --profile pune_test \
  --input-run data/synthetic/<run-id>
```

Repeat `--input-run` for independently seeded runs. The builder verifies every source Parquet hash
against its generator manifest before reading it. New experiment manifests declare `train`,
`validation`, `test`, or `stress_test`; those roles determine `run_holdout_split`. Directory order
never decides the role. Development runs remain `not_available` for cross-seed claims, and they
cannot be mixed with explicitly declared runs.

Quality checks:

```bash
uv run pytest
uv run ruff check src tests
uv run mypy src
```

This step does not train either model. Training begins only after the feature manifest, audit,
distributions, and class balance are approved.

## 9. What synthetic correctness can and cannot prove

The current tests can make the synthetic dataset internally consistent, reproducible, causal, and
hard to leak. They cannot guarantee that artificial Pune behavior matches real Pune drivers.
Avoiding model overfitting therefore also requires:

1. at least three seeds and scenario holdouts;
2. simple baselines and regularized models;
3. rolling time-fold evaluation;
4. error breakdowns by zone, horizon, cold start, and scenario;
5. calibration on genuine pilot data as soon as it arrives;
6. keeping synthetic and real headline metrics separate.
