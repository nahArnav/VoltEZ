# Model 1 FastAPI integration handoff

The backend should load the model once during application startup. Public clients should request a
zone/time forecast; they should never construct the 52 ML features themselves. A backend feature
service must build them from point-in-time database state, then call the internal predictor.

## Startup and internal endpoint

FastAPI belongs in the backend repository, so it is intentionally not added as an ML-package
dependency. The backend can use this adapter:

```python
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException

from voltez_ml.serving.demand import (
    DemandFeatureRequest,
    DemandInputError,
    DemandPredictionResponse,
    DemandPredictor,
)

BUNDLE = Path("models/demand/voltez-demand-60m-pune-v1")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.demand_predictor = DemandPredictor.from_artifact(
        BUNDLE,
        BUNDLE / "feature_contract.json",
    )
    yield


app = FastAPI(lifespan=lifespan)


@app.post("/internal/ml/v1/demand", response_model=DemandPredictionResponse)
def predict_demand(body: DemandFeatureRequest) -> DemandPredictionResponse:
    try:
        return app.state.demand_predictor.predict(body)
    except DemandInputError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
```

For route planning or a heatmap, call `predict_batch` once for all zones. This produces the same
answers as single prediction while avoiding one estimator call per zone.

## Response semantics

```json
{
  "model_id": "demand-window-60m-hgbr-bdb1d74f9ce09d73",
  "zone_id": "zone-hinjawadi",
  "prediction_origin": "2026-08-22T10:00:00+05:30",
  "target_window_start": "2026-08-22T10:15:00+05:30",
  "target_window_end": "2026-08-22T11:15:00+05:30",
  "expected_requests": 1.72,
  "rounded_requests": 2,
  "quality": "in_domain",
  "used_fallback": false,
  "warnings": [],
  "outside_training_range": []
}
```

- `expected_requests` is the value used for ranking, heatmaps, and capacity decisions.
- `rounded_requests` is a display convenience only.
- `warning` means prediction was allowed but one or more inputs were beyond training experience.
- `fallback` means the model was bypassed and historical seasonal demand was returned.
- A 422 means the feature vector was structurally or semantically invalid and must be rebuilt.

## Point-in-time feature flow

1. Receive `zone_id` and prediction origin.
2. Read only events with timestamps strictly before the origin.
3. Compute the same v3 lag, rolling, zone, calendar, context, and missingness fields.
4. Construct `DemandFeatureRequest` internally.
5. Call `predict` or `predict_batch`.
6. Persist the output and feature snapshot identity.
7. After the target window closes, aggregate observed searches/requests/bookings/sessions and attach
   the realized demand label for monitoring.

Persist predictions to `ml_lab.ml_predictions` with entity/zone ID, model ID, prediction type,
target time, expected value, quality state, and generation time. Store the exact feature payload or
snapshot reference in `ml_lab.feature_snapshots`. Never overwrite old predictions during a model
upgrade.

## Failure behavior

| Situation | Behavior |
|---|---|
| Missing/extra feature | Reject with 422 |
| Negative count, invalid binary/rate, bad coordinate | Reject with 422 |
| Calendar encoding disagrees with origin | Reject with 422 |
| One or a few rare but valid values | Predict with `quality=warning` |
| Many features beyond training distribution | Return seasonal fallback |
| Model file or contract hash mismatch | Fail startup and keep service unhealthy |

The backend should cache the successfully loaded predictor, not individual predictions. Prediction
caching may be keyed by `(model_id, zone_id, prediction_origin, feature_snapshot_id)`.

## Shadow rollout and monitoring

Start with `MODEL1_MODE=shadow`: return forecasts to internal dashboards and store them, but do not
change booking availability or pricing. An n8n job can aggregate completed windows daily and alert
on:

- seven-day MAE or WAPE degradation;
- absolute mean bias above an approved threshold;
- fallback rate above 5%;
- feature-contract rejection spikes;
- top-decile precision decline;
- zone/hour drift, especially the 17:00–20:00 peak.

Render can host the service and health endpoint. The health response should include bundle ID,
model hash, contract hash, loaded state, and deployment stage—but never secrets or raw user data.
