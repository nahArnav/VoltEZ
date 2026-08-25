# Step 7 — Multi-seed experiment readiness

This step protects VoltEZ from reporting an impressive score that came from memorizing one
synthetic world. It creates experiment definitions and a no-write preflight report. It does not
generate the 90-day datasets and it does not train either model.

## 1. Five dynamic worlds in one stable Pune network

| Profile | Role | Seed | May fit a model? | Purpose |
|---|---|---:|---|---|
| `train_seed_01` | train | 20260821 | Yes | First ordinary Pune realization |
| `train_seed_02` | train | 20260917 | Yes | Stops training from depending on one lucky random draw |
| `validation_seed_01` | validation | 20261013 | No | Select features and hyperparameters |
| `test_seed_01` | test | 20261109 | No | Locked final baseline score, inspected once |
| `stress_seed_01` | stress test | 20261205 | No | Robustness under more disruptions; never a headline metric |

Every canonical row above uses structural seed `20260821`. Its listed seed is the independent
dynamic seed: changing it changes drivers, requests, outages, bookings, sessions, context, and
labels while retaining the same zone, business, charger, port, tariff, and inherent health
profiles. Two training seeds therefore teach the model varying histories inside one deployable
Pune network instead of five unrelated artificial cities.

Train, validation, and test use the exact same baseline parameters. Only their seeds differ. This
makes their scores comparable. The stress run intentionally raises monsoon, event, outage, and
stale-report frequency. Mixing that run into headline evaluation would make the baseline metric
ambiguous, so its manifest role remains `stress_test`.

## 2. Why roles live in configuration and manifests

Every experiment overlay changes two fields:

- `project.seed` controls the random realization;
- `experiment.evaluation_role` controls the legal use of that realization.

`project.structural_seed` normally remains fixed. The optional
`structural_shift_seed_01` profile changes it and exists only for a separate out-of-distribution
robustness run. It must not replace `stress_seed_01` in the canonical five-world suite.

The generator includes both values in the run identity and `manifest.json`. The feature builder
reads the declared role from the manifest. It does not infer roles from filenames or lexical
directory order. Consequently, renaming or reordering folders cannot turn locked test rows into
training rows.

Feature rows contain two different split columns:

- `split` is the purged chronological train/validation/test window *inside one world*;
- `run_holdout_split` is the independent-world role declared by the manifest.

Future training code must gate first on `run_holdout_split`. A row from the locked test world must
never fit a model even if its within-world `split` value happens to be `train`. The temporal column
exists for rolling backtests; the run-level column protects independent evaluation.

Legacy development manifests remain supported for small local checks. Mixing an explicitly
declared run with a development-role run is rejected, because that usually means somebody forgot
to assign a role.

## 3. Run the no-write preflight

After installing the local package entry points, run:

```bash
uv run voltez-plan-data --profile pune_v1
```

The command checks:

1. all dynamic seeds and experiment names are unique;
2. at least two training seeds exist;
3. exactly one validation seed and one test seed exist;
4. all canonical roles share one structural seed and baseline train/validation/test generator
   distributions are identical;
5. each planned run is below its configured row safety ceiling;
6. the stress distribution is separate from headline evaluation;
7. conservative memory estimates respect the Apple M4 budget.

It prints JSON to standard output and never writes a dataset. Exit code `0` means the plan has no
hard failure. `ready_with_warnings` is expected for the full 90-day plan because combining every
baseline run into pandas at once is conservatively estimated above the 10 GB project budget.

## 4. M4 / 16 GB interpretation

The current full profile estimates about 3.47 million raw and derived rows per run. The preflight
uses 2,500 bytes per planned row as a deliberately conservative working-memory ceiling. This is
not a measured Parquet size and should not be presented as a benchmark.

The safe execution policy is:

1. generate one run;
2. validate its manifest and table hashes;
3. record actual elapsed time, peak memory, disk usage, and class distributions;
4. release memory before starting the next run;
5. build combined features only after the small multi-seed rehearsal proves the memory strategy.

The current feature builder loads source runs into pandas. Therefore, do not build all four
90-day baseline runs together yet. Step 8 should add or verify partitioned/streaming assembly from
measured rehearsal results if the conservative warning is confirmed.

## 5. Parameter effects

| Parameter | What changes when increased | Main risk |
|---|---|---|
| `synthetic.days` | More seasonal/time examples | Longer generation and larger features |
| `zone_count` | More spatial variety | Sparse zones can become hard to learn |
| `driver_count` | More user/vehicle combinations | Static-table memory grows |
| `average_requests_per_zone_per_day` | More demand events and positive availability evidence | Unrealistically dense demand if uncalibrated |
| `negative_binomial_dispersion` | Changes burstiness around the average | Extreme spikes may dominate losses |
| `scenario_mix` | Frequency of ordinary and disrupted days | Changing baseline test mix makes metrics incomparable |
| `base_operational_probability` | Proportion of normally working ports | Can make availability labels too imbalanced |
| status-report error probabilities | Noise in reported evidence | Excess noise can hide real signal |
| `memory_budget_gb` | Allowed planning ceiling, not physical RAM | Raising it does not create more memory |

Synthetic consistency is not the same as real-world accuracy. The generator can be logically
immaculate relative to its assumptions and still model Pune incorrectly. Before industry claims,
replace assumptions with pilot telemetry and report synthetic and real metrics separately.

## 6. Sponsor use without contaminating ML evaluation

Sponsor products should have auditable, meaningful boundaries:

- **n8n** can later orchestrate the five generation/validation jobs sequentially and stop on a
  non-ready report. It must not rewrite manifests or labels.
- **Render** can host the FastAPI inference service and a read-only model-health endpoint after
  training. Local M4 training artifacts should be versioned before deployment.
- **CodeMate AI** can review leakage tests, typing, and failure paths. Human review and automated
  tests remain the source of truth.
- **Tavily** can later fetch source-attributed public event context for real inference. Fetched
  events must be timestamped by when VoltEZ knew them, or they can leak future information.
- **Gemini/Lyzr** can explain numeric predictions using stored model outputs and feature reasons.
  They must not invent demand/availability probabilities or modify test results.
- **Google for Developers / MLH / StartupEd / Swytchcode** are suitable for tooling, mentorship,
  demo communication, and reviewed implementation support; they are not substitutes for held-out
  evaluation.

Credentials are not required for Step 7. Sponsor adapters should only be added when access is
allotted and the exact interface is approved.

## 7. Approval boundary

Completing Step 7 means configuration, manifests, role-aware splitting, preflight validation,
tests, and this explanation are ready. It does not authorize:

- generating the full five-run 90-day dataset;
- fitting either ML model;
- looking at the locked test labels during development;
- pushing commits to GitHub.
