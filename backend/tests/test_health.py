import json
from types import SimpleNamespace

import pytest

import app.main as main_module
from app.main import create_app


class _HealthyConnection:
    async def __aenter__(self):
        return self

    async def __aexit__(self, *_args):
        return None

    async def execute(self, _statement):
        return None


class _HealthyEngine:
    def connect(self):
        return _HealthyConnection()


class _HealthyRedis:
    async def ping(self):
        return True


class _FailingEngine:
    def connect(self):
        raise ConnectionError("database unavailable")


def _readiness_endpoint(app):
    return next(
        route.endpoint
        for route in app.routes
        if getattr(route, "path", None) == "/health/ready"
    )


@pytest.mark.asyncio
async def test_readiness_reports_healthy_only_when_dependencies_and_models_are_ready(monkeypatch):
    app = create_app()
    app.state.redis = _HealthyRedis()
    app.state.ml_ready = True
    bundle = SimpleNamespace(model_id="test-model", stage="production", feature_count=2, artifact_hash="a" * 64)
    app.state.demand_bundle = bundle
    app.state.availability_bundle = bundle
    monkeypatch.setattr(main_module, "engine", _HealthyEngine())

    response = await _readiness_endpoint(app)(SimpleNamespace(app=app))

    assert response.status_code == 200
    payload = json.loads(response.body)
    assert payload["status"] == "ready"
    assert payload["checks"] == {"database": True, "redis": True, "ml": True}


@pytest.mark.asyncio
async def test_readiness_returns_503_when_a_dependency_is_unavailable(monkeypatch):
    app = create_app()
    app.state.redis = _HealthyRedis()
    app.state.ml_ready = True
    bundle = SimpleNamespace(
        model_id="test-model",
        stage="production",
        feature_count=2,
        artifact_hash="a" * 64,
    )
    app.state.demand_bundle = bundle
    app.state.availability_bundle = bundle
    monkeypatch.setattr(main_module, "engine", _FailingEngine())

    response = await _readiness_endpoint(app)(SimpleNamespace(app=app))

    assert response.status_code == 503
    payload = json.loads(response.body)
    assert payload["status"] == "not_ready"
    assert payload["checks"]["database"] is False
    assert payload["checks"]["redis"] is True
