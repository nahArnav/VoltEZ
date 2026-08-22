# Step 13C: two-stage demand hurdle candidate

Status: source implementation and automated tests complete; final-data training is approval-gated.

## Why this candidate exists

The 60-minute Poisson benchmark generalizes cleanly, but it smooths the two ends of demand. On the
validation world it predicts about 0.65 requests when the truth is zero and about 1.61 when the
truth is in the 3+ band, whose mean is 3.64. Its almost-zero overall bias therefore hides errors
that cancel each other.

The hurdle candidate asks two easier questions instead of forcing one estimator to explain both
zero occurrence and positive severity:

1. `occurrence_probability = P(request_count > 0 | features)`
2. `positive_mean = E[request_count | request_count > 0, features]`
3. `expected_demand = occurrence_probability * positive_mean`

Example: if demand has a 70% chance of occurring and its expected size when present is 2.5,
VoltEZ returns `0.70 * 2.5 = 1.75` expected requests. There is no arbitrary 0.5 classification
threshold in this calculation, so useful probability information is not discarded.

## What each stage learns

The occurrence stage is a histogram gradient-boosting classifier trained on every row. Its target
is one for any positive request count and zero otherwise. Log loss penalizes confident incorrect
probabilities, while Brier score, average precision, and ROC AUC reveal probability quality and
ranking quality.

The positive-count stage is a histogram gradient-boosting Poisson regressor trained only on rows
where demand is greater than zero. It learns the conditional mean of positive demand. Predictions
are floored at one because a conditional positive count cannot have a mean below the smallest
allowed positive count.

Both stages use the Apple M4 CPU. Scikit-learn's histogram boosting does not use Metal/MPS; forcing
MPS would require changing libraries and would not make this tabular workload more trustworthy.

## Parameter effects

| Parameter | What increasing it usually does | Main risk |
|---|---|---|
| `*_max_iter` | Adds more boosting corrections | Can fit noise and increases training time |
| `*_learning_rate` | Makes each correction stronger | Can become unstable or overfit |
| `*_max_leaf_nodes` | Learns more detailed interactions | Can memorize narrow synthetic patterns |
| `*_l2_regularization` | Shrinks complex leaf values | Too much can underfit peaks |
| `maximum_training_rows` | Uses more observations | More memory/time; no benefit if rows are redundant |
| `random_seed` | Makes sampling and estimators repeatable | Changing it changes the experiment identity |

Classifier and count-stage controls are separate because occurrence and severity can need different
complexity. Defaults deliberately match the Poisson benchmark's conservative boosting scale.

## Fair-comparison and leakage safeguards

- The hurdle candidate uses the same Pune v3 feature-suite manifest as the benchmark.
- It uses the same 60-minute rolling target and 15-minute forecast lead.
- It selects the same causal numeric feature contract.
- Training roles are the two training worlds; selection uses validation and stress worlds.
- The final test role is never loaded unless `--unlock-test` is explicitly supplied.
- Artifact manifests hash the source, feature suite, model file, report, settings, and Git state.
- The generic evaluator records occurrence, positive-count, and final expected-demand diagnostics.

## Training command for the next approved step

Do not add `--unlock-test` during model development.

```bash
uv run voltez-train-demand-hurdle-window \
  --feature-suite-manifest data/final/pune_v3/features/feature_suite_manifest.json \
  --output-root artifacts/demand_hurdle_v3 \
  --window-minutes 60 \
  --forecast-lead-minutes 15 \
  --bucket-minutes 15
```

Training alone does not make the hurdle model the winner. It must be evaluated on the same train,
validation, and stress roles as Poisson. Compare final MAE/RMSE/WAPE and Poisson deviance, then
inspect zero-target MAE, non-zero underprediction, the 3+ band, occurrence Brier/AP, conditional
positive-count MAE, hourly peaks, zones, and calibration. The locked test stays untouched until the
model family and settings have been frozen.

## Knowledge check

1. Why can the final expected prediction be below one even though `positive_mean` is at least one?
2. Why is the positive-count model forbidden from training on zero-demand rows?
3. Why must Poisson and hurdle use the identical feature suite and rolling target?
4. If classifier probability improves but conditional-count error worsens, what must decide whether
   the whole model improved?
