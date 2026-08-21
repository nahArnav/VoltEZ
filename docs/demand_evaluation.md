# Step 10B — Demand evaluation and the 60-minute experiment

## Outcome

The published 15-minute point-demand model is a sound expected-intensity baseline: it generalizes
with a small train-to-validation gap and does not collapse on the stress world. Its operational
weakness is target sparsity. About 80.6% of zone/bucket targets are zero, so a conditional-mean
Poisson prediction is deliberately smooth and is not a surge alert by itself.

The first improved experiment predicts a rolling 60-minute request total. It reduces validation
zero support to 46.8% and makes the output easier to use in demand heatmaps and capacity planning.
The locked test world was not loaded by either experiment.

## Controlled validation comparison

Raw MAE values cannot be compared between targets because a 60-minute total has about four times
the target scale. WAPE, baseline improvement, calibration, robustness, and product meaning are the
fairer comparisons.

| Measurement | 15-minute point | 60-minute rolling sum |
|---|---:|---:|
| Validation rows | 1,033,512 | 206,976 |
| Mean target | 0.235 | 0.940 |
| Zero-target rate | 80.6% | 46.8% |
| Model MAE | 0.350 | 0.790 |
| Aligned seasonal MAE | 0.366 | 0.974 |
| MAE improvement over seasonal | 4.6% | 18.9% |
| Model RMSE | 0.514 | 1.072 |
| Seasonal RMSE | 0.715 | 1.449 |
| RMSE improvement over seasonal | 28.1% | 26.1% |
| WAPE | 1.487 | 0.841 |
| Average precision | 0.302 | 0.724 |
| Nonzero prevalence | 0.194 | 0.532 |

The 60-minute stress WAPE is 0.875 versus validation WAPE 0.841. That small shift is evidence that
the frozen model remains stable under the current monsoon/event/outage stress mix. Both worlds are
synthetic and produced by one generator family, so this is not a substitute for real-world data.

## Causal target construction

For a prediction origin `t` and 15-minute buckets, the rolling target is:

```text
target_60m(t) = requests(t+15) + requests(t+30) + requests(t+45) + requests(t+60)
```

The feature vector is taken only from the row at `t`. The latest operational evidence in that row
is from `t-15` or earlier. Future rows contribute their observed request counts to the label, never
their operational features.

Yesterday/week comparison values are a special case. The values corresponding to all four future
clock slots occurred one day or one week earlier, so they are already known at `t`. The builder
therefore adds:

- `request_sum_same_window_yesterday`
- `request_sum_same_window_last_week`
- explicit missing flags for both windows

The seasonal baseline uses last week, then yesterday, then the origin-anchored EWM fallback. It
never uses an EWM calculated at a future origin.

## Why the previous seasonal baseline changed

The original point baseline used the yesterday/week lag aligned to the prediction origin. A
15-minute forecast should instead compare against the historical value aligned to the future target
clock slot. The reusable evaluator now performs this target-time alignment. This makes the baseline
fairer: the published point model still wins, but its validation MAE advantage is 4.6%, not the 6.8%
reported against the older origin-aligned baseline.

## Reusable evaluator safeguards

`voltez-evaluate-demand` performs the same evaluation contract for point and rolling-window
artifacts:

1. Verify the model artifact SHA-256.
2. Verify that the feature-suite hash equals the one recorded during training.
3. Load validation and, unless skipped, stress.
4. Load train only when `--include-train` is requested.
5. Never load the test role unless `--unlock-test` is explicitly supplied.
6. Report model and seasonal metrics, calibration deciles, demand bands, hour/weekend/zone slices,
   nonzero ranking, and permutation importance.
7. Write an immutable, hashed JSON report under `reports/demand/`.

Example:

```bash
uv run voltez-evaluate-demand \
  --artifact-dir artifacts/demand/demand-hgbr-66569ba82deedaa3 \
  --include-train \
  --permutation-sample-rows 50000 \
  --permutation-repeats 3
```

Do not pass `--unlock-test` during feature selection, model selection, calibration, or threshold
selection.

## Train the rolling-window experiment

```bash
uv run voltez-train-demand-window \
  --feature-suite-manifest data/final/pune_v1/features/feature_suite_manifest.json \
  --window-minutes 60 \
  --forecast-lead-minutes 15 \
  --bucket-minutes 15 \
  --max-iter 250 \
  --learning-rate 0.05 \
  --max-leaf-nodes 31 \
  --l2-regularization 0.2 \
  --maximum-training-rows 1500000
```

Parameter logic:

| Parameter | Meaning | Main risk when increased |
|---|---|---|
| `window-minutes` | future demand accumulated into one target | loses short-lived timing detail |
| `forecast-lead-minutes` | delay before the first predicted bucket | forecasts become harder farther ahead |
| `max-iter` | number of boosting corrections | extra runtime and overfit |
| `learning-rate` | strength of each correction | instability or synthetic-pattern memorization |
| `max-leaf-nodes` | interaction complexity | zone/time quirks may be memorized |
| `l2-regularization` | shrinkage of extreme leaf values | too much produces underfit averages |

## What should happen next

The 60-minute experiment is a better operational forecast target, but time-of-day still dominates
permutation importance. Step 10C should correct the synthetic-world structure before adding a more
complex model:

1. Keep Pune zone identities and structural baseline profiles fixed across ordinary train,
   validation, and test worlds.
2. Vary dynamic demand noise, users, events, weather, outages, and reporting delays by seed.
3. Reserve a separate structural-shift world for out-of-distribution robustness.
4. Add cutoff-safe context features and stable zone/category features.
5. Then compare the Poisson baseline with a hurdle model for nonzero probability plus conditional
   count, while keeping test locked.

## Knowledge check

1. Why may a prediction of `0.2` be correct even when the realized 15-minute target is `1`?
2. Which rows supply model features for the 60-minute target, and which rows supply labels?
3. Why are future-slot yesterday/week values safe while a future row's EWM is unsafe?
4. Why should raw MAE not be compared directly between the 15-minute and 60-minute targets?
5. What exact flag would unlock test, and why must it remain absent during Step 10B?
