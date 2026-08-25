# VoltEZ Model 2 — Availability Training Guide

Status: Step 2 development implementation; locked test remains unopened
Dataset: Pune v4, label definition v1.3, feature view v3

## 1. What this model answers

Model 2 estimates:

`P(physical port is unavailable within 10 minutes of the driver's ETA)`

The positive class is `unavailable`. This makes safety failures explicit in metrics such as
unavailable precision, recall, and PR-AUC.

The model does not decide whether a candidate is legally or transactionally bookable. The backend
must first reject deterministic failures:

- incompatible vehicle connector;
- closed or inaccessible host;
- no approved availability window;
- known active fault or maintenance;
- confirmed overlapping booking;
- suspended or unverified host/charger.

ML runs only for candidates that pass these gates. It estimates the uncertainty left by future
session overruns, report quality/freshness, recent congestion, ETA, and historical reliability.

## 2. Label truth

Known labels come from trustworthy evidence:

- `available`: verified `service_ready_at <= ETA + 10 minutes`, or strong independent evidence;
- `unavailable`: verified readiness after the tolerance or a verified pre-service failure;
- `unknown`: no trustworthy reconstruction, cancellation, no-show, unobserved candidate, or a
  driver who arrived too late to prove the ETA-time state.

Only available/unavailable rows enter supervised fitting. Unknown rows remain in the all-outcomes
table for coverage and censoring analysis. They are never changed into unavailable.

## 3. Feature boundary

The trainer uses a fixed allowlist of 35 causal features in the current Pune v4 suite:

- ETA and cyclic target-time features;
- nearby known bookings and active-session state at prediction time;
- causal recent session successes/failures and Bayesian-smoothed reliability;
- latest status, source, confidence, age, and expiry;
- recent zone requests, unserved demand, and occupancy;
- connector, charging type, power, site size, host category, and access type.

It rejects or ignores IDs, raw timestamps, split metadata, label source/confidence as features,
target-time booking/port state, arrival time, and `service_ready_at`. Zone IDs are also excluded so
the classifier must learn operational relationships rather than memorize Pune zone names.

`label_confidence` is not a feature. It is only a small sample weight, so stronger evidence can
carry slightly more fitting influence without revealing the answer to the estimator.

## 4. Compared approaches

The evaluation report contains three baselines and one candidate:

1. **Always available:** exposes why ordinary accuracy is misleading with an 11–12% unavailable
   rate. It gets about 88% accuracy while catching zero unavailable ports.
2. **Latest fresh status:** uses only fresh available/occupied/faulted evidence.
3. **Logistic regression:** a linear, one-hot-encoded baseline for all causal features.
4. **Histogram gradient boosting:** learns nonlinear combinations and interactions.

The candidate uses balanced class weight while fitting so the minority unavailable examples are
not ignored. Raw class-balanced probabilities intentionally overstate unavailable risk, so they
must be calibrated before application use.

## 5. Why calibration is leakage-safe

There are two independent training worlds. Calibration proceeds as follows:

1. Fit on training world A and predict world B.
2. Fit on world B and predict world A.
3. Combine those out-of-world probabilities.
4. Fit a Platt sigmoid from raw probability to observed unavailable rate.
5. Refit the base classifier on both training worlds.

The calibrator therefore never sees a probability produced on the same world used to fit its base
classifier. Validation labels are not used for calibration; they are reserved for decision policy.

Calibration changes probability meaning, not ranking. ROC-AUC and PR-AUC therefore stay the same,
while Brier score, log loss, and expected calibration error should improve substantially.

## 6. Three-state application decision

The API should not force every probability into a binary answer:

- low unavailable probability → `available`;
- middle range → `unknown`;
- high unavailable probability → `unavailable`.

Validation selects the low threshold for maximum coverage while keeping the observed unavailable
risk among `available` decisions at or below 5%. It selects the high threshold for maximum recall
while targeting at least 60% precision for explicit `unavailable` decisions.

These thresholds are product choices, not universal truths. The probability should also be used in
charger ranking. A 0.30 risk can reduce a charger's recommendation score even when it stays in the
`unknown` band.

If there is no status evidence, the serving layer returns `unknown` rather than asking the model to
extrapolate from a feature state absent from supervised training.

## 7. Metrics that matter

- **PR-AUC:** ranking quality for the minority unavailable class; compare it with class prevalence.
- **ROC-AUC:** general pairwise ranking quality.
- **Brier score / log loss:** probability accuracy, not just class labels.
- **Expected calibration error:** whether predicted risk matches observed frequency.
- **Available precision:** how often a confident available answer is truly available.
- **Unsafe available rate:** unavailable truth among confident available answers.
- **Unavailable precision/recall:** trustworthiness and coverage of explicit warnings.
- **Abstention rate:** how often the model honestly returns unknown.

Accuracy alone must never select this model because always predicting available already exceeds
88% accuracy.

## 8. Parameter effects

| Parameter | Increasing it does what? | Main risk |
|---|---|---|
| `max_iter` | Adds boosting rounds | More overfitting and runtime |
| `learning_rate` | Learns faster per tree | Less stable generalization |
| `max_leaf_nodes` | Learns more complex interactions | Memorizes synthetic patterns |
| `min_samples_leaf` | Requires broader evidence per rule | Can miss small but genuine failure patterns |
| `l2_regularization` | Shrinks complex tree effects | Too much causes underfitting |
| `target_available_risk` | Allows more risky ports to be called available | Worse driver trust |
| `target_unavailable_precision` | Makes explicit unavailable warnings stricter | Lower unavailable recall |
| `minimum_threshold_rows` | Requires more validation evidence per threshold | Can prevent useful rare-state warnings |

The defaults favor safe, explainable decisions rather than maximum binary recall.

## 9. Local Apple M4 command

```bash
uv sync --group dev

uv run voltez-train-availability \
  --feature-suite-manifest data/final/pune_v4/features/feature_suite_manifest.json \
  --output-root artifacts/availability
```

This implementation uses scikit-learn histogram boosting on the Apple M4 CPU. MPS is not used
because scikit-learn does not support it for this estimator; forcing a GPU flag would be fake
hardware acceleration rather than a speed improvement.

The command reads train, validation, and stress only. There is deliberately no `--unlock-test`
option in the Step 2 trainer.

## 10. Step 2 development rehearsal

The first uncommitted-source rehearsal produced the following evidence. These are development
metrics, not final locked-test claims:

| Metric | Validation | Stress |
|---|---:|---:|
| ROC-AUC | 0.8031 | 0.8088 |
| PR-AUC | 0.3275 | 0.3349 |
| Unavailable prevalence | 0.1187 | 0.1198 |
| Brier score | 0.0907 | 0.0908 |
| Calibration error, 10 bins | 0.0065 | 0.0064 |
| Three-state coverage | 69.47% | 68.91% |
| Accuracy on decided rows | 94.65% | 94.67% |
| Available precision | 95.05% | 95.23% |
| Explicit unavailable precision | 61.54% | 53.74% |
| Explicit unavailable recall | 4.20% | 4.17% |

PR-AUC is about 2.76 times validation prevalence and exceeds the logistic baseline of 0.2929.
Calibration reduces Brier score below the constant-prevalence baseline of 0.1046.

Explicit unavailable recall is intentionally low because the current 60% precision target refuses
to turn moderate risk into a hard warning. Most uncertain cases become `unknown`, while the
continuous probability remains available to ranking. This trade-off must be shown honestly; it is
not equivalent to saying the model catches every future failure.

Permutation evaluation says the strongest drivers are latest status, ETA, status age, active
session elapsed time, connector type, and prior reliability evidence. This is operationally
plausible and does not depend on entity IDs or a hidden target formula.

All seven development gates passed. The next artifact must be retrained from committed clean source
before it can be considered a frozen candidate.

## 11. Real-world path and sponsors

Synthetic validation proves pipeline logic, not Pune production accuracy. After the backend emits
real impressions, arrivals, sessions, status evidence, and outcomes:

- Render can host the FastAPI probability service and scheduled monitoring jobs;
- n8n can orchestrate approved feature refresh and retraining workflows;
- Swytchcode can govern external status/context API calls;
- Google services can supply real route ETA before feature construction;
- Tavily can discover public event/context sources with provenance;
- CodeMate AI can review leakage tests and feature contracts;
- Gemini/Lyzr may explain a numeric result but must never invent or override it.

The first production stage is shadow mode: store probabilities and decisions without changing
bookings, then measure calibration and slice performance against real outcomes.

## 12. Knowledge check

1. Why is unavailable the positive class even though available is more common?
2. Why would 88% accuracy be useless evidence for this dataset?
3. Why are two independent training worlds used for calibration?
4. What is the difference between a hard backend gate and a model feature?
5. Why does a missing status produce unknown instead of unavailable?
6. What happens to recall when unavailable precision is raised from 50% to 70%?
7. Why can calibration improve Brier score without changing ROC-AUC?
