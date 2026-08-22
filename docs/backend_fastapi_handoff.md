# FastAPI handoff for Models 1 and 2

This contract matches the current `Backend` branch: the application factory is
`services/api/app/main.py`, shared integrations live under `services/api/app/integrations`, and
routes are mounted from `services/api/app/api/v1/router.py` below `/api/v1`.

No backend code is changed from the ML branch. The backend team can merge or install this package,
copy the two promoted model bundles, and add the thin wiring below.

## Responsibilities

| Layer | Responsibility |
|---|---|
| PostgreSQL/backend service | Apply hard eligibility gates and build point-in-time features |
| `DemandPredictor` | Validate Model 1 features and return a 60-minute request forecast |
| `AvailabilityPredictor` | Validate Model 2 features and return available/unknown/unavailable |
| FastAPI router | Translate validation errors to HTTP 422 and return the Pydantic response |

The backend must apply connector compatibility, host access, approved availability windows,
active faults, overlapping bookings, and business verification before invoking Model 2. ML must
never override those transactional truths.

## Runtime installation

Use Python 3.12 and install the ML package from the repository root with its checked-in `uv.lock`.
This is important because joblib/scikit-learn artifacts should be loaded with the same library
versions used during training.

```bash
cd /path/to/VoltEZ
uv sync --frozen
```

The current backend requirements do not include NumPy, pandas, joblib, scikit-learn, or the
`voltez-ml` package. Do not manually duplicate those versions in `services/api/requirements.txt`;
use the root lockfile when the branches are integrated.

## Backend configuration

Add bundle paths to `services/api/app/core/config.py` when the backend team integrates ML:

```python
from pathlib import Path

MODEL1_BUNDLE: Path = Path("models/demand/voltez-demand-60m-pune-v1")
MODEL2_BUNDLE: Path = Path("models/availability/voltez-availability-pune-v1")
```

Load each predictor once—not once per request—in the FastAPI lifespan:

```python
from contextlib import asynccontextmanager

from fastapi import FastAPI
from voltez_ml.serving.availability import AvailabilityPredictor
from voltez_ml.serving.demand import DemandPredictor


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.demand_predictor = DemandPredictor.from_artifact(
        settings.MODEL1_BUNDLE,
        settings.MODEL1_BUNDLE / "feature_contract.json",
    )
    app.state.availability_predictor = AvailabilityPredictor.from_artifact(
        settings.MODEL2_BUNDLE,
        settings.MODEL2_BUNDLE / "feature_contract.json",
    )
    yield
```

Pass `lifespan=lifespan` when constructing the existing `FastAPI` object.

## Versioned internal endpoints

Create `services/api/app/api/v1/ml.py`, then include its router from the existing v1 router:

```python
from fastapi import APIRouter, HTTPException, Request

from voltez_ml.serving.availability import (
    AvailabilityFeatureRequest,
    AvailabilityInputError,
    AvailabilityPredictionResponse,
)
from voltez_ml.serving.demand import (
    DemandFeatureRequest,
    DemandInputError,
    DemandPredictionResponse,
)

router = APIRouter(prefix="/internal/ml", tags=["Internal ML"])


@router.post("/demand", response_model=DemandPredictionResponse)
def demand(body: DemandFeatureRequest, request: Request) -> DemandPredictionResponse:
    try:
        return request.app.state.demand_predictor.predict(body)
    except DemandInputError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error


@router.post("/availability", response_model=AvailabilityPredictionResponse)
def availability(
    body: AvailabilityFeatureRequest, request: Request
) -> AvailabilityPredictionResponse:
    try:
        return request.app.state.availability_predictor.predict(body)
    except AvailabilityInputError as error:
        raise HTTPException(status_code=422, detail=str(error)) from error
```

Then add `api_router.include_router(ml.router)` in `services/api/app/api/v1/router.py`. The resulting
paths are `/api/v1/internal/ml/demand` and `/api/v1/internal/ml/availability`.

## Feature-service rules

- Public clients send zone, vehicle, port, and ETA inputs; they never send raw ML features.
- The backend calculates features from records whose event times are no later than
  `prediction_origin`.
- Preserve the feature names exactly; the contract rejects missing and extra fields.
- Model 2 verifies that ETA and calendar encodings agree with the request timestamps.
- Missing status, unseen categories, or major distribution shift returns `unknown` rather than a
  fabricated binary answer.
- Persist the response and feature snapshot in `ml_lab.ml_predictions` and
  `ml_lab.feature_snapshots` using `model_id` for traceability.

Start both models in shadow mode. Model 1 may power heatmaps after its monitoring gates pass;
Model 2 should initially influence ranking while deterministic backend gates remain authoritative.
