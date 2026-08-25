# Model 1 model card: 60-minute Pune demand forecast

Status: **synthetic-validated deployment candidate**. The ML implementation is complete. Real
VoltEZ shadow traffic is required before calling it production-validated.

## Intended use

Model 1 estimates the number of charging requests expected in a Pune zone during a 60-minute
window beginning 15 minutes after the prediction origin. It supports demand heatmaps, charger
ranking, owner dashboards, off-peak recommendations, and operational planning.

It predicts a conditional mean, not the exact future. If the response is `1.7`, VoltEZ should read
that as “roughly 1–2 requests are expected,” not as a promise that exactly two drivers will arrive.
Random individual behavior makes exact demand unknowable even with a correctly specified model.

## Frozen champion

| Item | Value |
|---|---|
| Bundle | `voltez-demand-60m-pune-v1` |
| Model ID | `demand-window-60m-hgbr-bdb1d74f9ce09d73` |
| Artifact SHA-256 | `82418d51b203e4a7b8e4e7fe94133700c393ddbd80564e59696855197fba5e29` |
| Algorithm | Histogram gradient boosting with Poisson loss |
| Training rows | 413,952 |
| Features | 52 causal numeric features |
| Training worlds | Two independent 90-day Pune worlds |
| Target | 60-minute rolling request count, 15-minute lead |
| Execution | Apple M4 CPU; no MPS is used by scikit-learn histogram boosting |

The artifact is at `models/demand/voltez-demand-60m-pune-v1/`. Its deployment manifest hashes the
model, feature contract, training report, pre-test selection record, robustness audit, and one-time
locked-test report.

## Model selection

The Poisson benchmark was compared with a two-stage hurdle model and three additional Poisson
capacity/regularization settings. The hurdle improved validation MAE by only 0.05% while slightly
worsening RMSE, Poisson deviance, and the 3+ demand band. The best tuning variant improved MAE by
only 0.014% and did not improve peaks. Both gains were below the pre-test 0.5% practical threshold,
so the simpler original Poisson model remained champion.

The champion artifact hash and selection rule were frozen before the locked test was opened.

## Evaluation results

| Role | MAE ↓ | RMSE ↓ | WAPE ↓ | Mean bias |
|---|---:|---:|---:|---:|
| Train | 0.726 | 0.965 | 0.810 | +0.0000 |
| Validation | 0.742 | 0.994 | 0.825 | +0.0026 |
| Stress | 0.756 | 1.010 | 0.807 | +0.0070 |
| Locked test | **0.739** | **0.990** | **0.825** | **+0.0021** |

Locked-test performance did not degrade relative to validation. On the one-time locked test:

- 75.89% of predictions were within one request of the observed count.
- 44.97% were within half a request.
- The top predicted demand decile contained non-zero demand 85.10% of the time.
- Mean prediction was 0.8983 versus a true mean of 0.8961.
- Seasonal baseline MAE was 0.9533, so the model reduced MAE by about 22.44%.

These are count-forecast results. “Correct most of the time” means useful expected-count accuracy,
ranking, and calibration—not exact clairvoyance for every random arrival.

## Robustness and arbitrary-input protection

The application does not pass unchecked random numbers directly to the estimator. The serving
contract verifies all 52 names and their order, timezone-aware prediction origins, finite values,
non-negative count semantics, binary/rate limits, cyclic calendar consistency, Pune geography,
and exactly one zone-type indicator.

The robustness audit sampled 5,000 validation and 5,000 stress rows:

- 100% produced finite non-negative responses.
- Serving and direct estimator predictions matched exactly.
- 0% needed fallback on the two legitimate unseen samples.
- Missing features, negative counts, and inconsistent calendar values were rejected.
- A valid-but-large multi-feature shift triggered the seasonal fallback.
- Repeated batch predictions were deterministic.

The response exposes `quality` as `in_domain`, `warning`, or `fallback`, along with affected
features. This is safer than letting a tree model silently produce a number for nonsense input.

## Known limitations

1. All train/validation/test worlds are synthetic. They are independent and logically audited, but
   they are not real VoltEZ traffic.
2. The conditional-mean forecast smooths peaks. On the locked test, true 3+ periods averaged 3.63
   requests while the model averaged 1.60 for those same rows.
3. The present bundle supports Pune zones and the v3 feature contract. New cities require data,
   geographic contract changes, and evaluation.
4. Exogenous context is useful only if known at prediction time and recorded with source and fetch
   timestamp.
5. Do not unlock or reuse the test world for further tuning. Future development needs new holdouts.

## Real-world validation plan

Deploy in shadow mode first: produce predictions but do not let them control bookings or pricing.
Store the prediction, feature version, input-quality state, and eventual observed request count.
Monitor MAE, WAPE, mean bias, within-one-request rate, top-decile precision, fallback rate, and
feature drift by zone and hour. Review weekly; retrain only after enough representative labels have
accumulated and create a new untouched temporal holdout.

No compatible public Pune session-demand dataset was found. Caltech's official
[ACN-Data](https://ev.caltech.edu/dataset.html) provides real workplace charging sessions and is a
useful external behavior reference, but it requires registration and represents United States
sites—not Pune demand ground truth. Caltech explicitly frames access to real data, realistic
simulation, and field testing as separate requirements for bridging theory and deployment in its
[ACN research portal](https://ev.caltech.edu/). VoltEZ follows that same separation instead of
claiming synthetic evaluation proves production accuracy.

## Sponsor integration boundaries

- **Render:** host the FastAPI service and immutable model bundle; expose health and model-version
  endpoints.
- **n8n:** schedule drift/quality reports and alert when fallback rate or residual metrics breach
  thresholds.
- **Tavily:** supply source-attributed events only through the context-ingestion pipeline; never let
  fetched text bypass feature validation.
- **Google for Developers / Gemini and Lyzr:** explain forecasts conversationally, but never change
  numeric outputs or invent confidence.
- **CodeMate AI:** review serving, tests, and API integration; it is not a training-data source.
- Other sponsor tools should be connected only when credentials are allocated and the integration
  has a real product role. Logos alone are not evidence of technical usage.

## Promotion rule

The bundle stage remains `synthetic_validated`. Promote it to production only after shadow labels
show acceptable performance across zones and peak hours, no critical input-contract failures, and
an explicit human approval recorded in `ml_lab.model_registry`.
