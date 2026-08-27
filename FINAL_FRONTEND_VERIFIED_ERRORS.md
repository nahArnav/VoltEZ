# VoltEZ `final-frontend` current error and readiness report

Reviewed branch: `final-frontend`
Reviewed local commit at start of this pass: `df25b9f`
Remote comparison after fetch: local was **0 commits behind** and **1 commit ahead** of `origin/final-frontend`; no remote changes were pending.
Review date: 2026-08-27

This is the current report. Defects from the original `errors.md` and the first
audit were rechecked; fixed items are listed separately so they are not
mistaken for active failures.

## Current shortcomings and deployment blockers

- `(backend/app/services/fcm.py) - Push delivery is still a development mock: notifications are persisted and sent over the in-app WebSocket, but no Firebase credentials or real FCM provider call is configured.`
- `(lib/core/network/razorpay_service.dart) - Web checkout intentionally fails with a clear mobile-only message because the Flutter Razorpay plugin has no web implementation; a production web payment adapter (for example Checkout.js) is still required if web payments are in scope.`
- `(backend/app/api/v1/session.py + lib/core/network/session_api.dart) - Session energy/telemetry is client-supplied/simulated; there is no physical charger/OCPP telemetry adapter. Production charging truth needs a provider integration and server-side meter readings.`
- `(backend/app/services/recommendation.py + database schema) - No tariff table/provider is implemented; cost uses the configured DEFAULT_PRICE_PER_KWH_INR fallback. A live tariff source is required for authoritative billing.`
- `(backend/app/api/v1/recommendations.py) - The business recommendation route returns an explicit placeholder response; owner-facing ML opportunity recommendations are not yet a real model-backed feature.`
- `(lib/core/network/business_api.dart) - A legacy mock business adapter remains in the repository. The active dashboard uses BusinessProvider and the live API, but the unused adapter is technical debt and can confuse future contributors.`
- `(lib/core/network/route_recommendation_api.dart + backend/app/api/v1/recommendations.py) - The live route request currently uses origin/vehicle/SOC and nearby chargers; destination-aware detour calculation and recommendation-impression persistence are not complete end-to-end.`
- `(backend/app/api/v1/ws.py + lib/core/network/session_websocket.dart) - JWT is still carried in the WebSocket query string. Use a short-lived ticket or a secured subprotocol at the edge before production deployment to avoid access-log leakage.`
- `(backend/app/services/ml_features.py + models/*) - The checked-in models are validated synthetic Pune artifacts. Real-world accuracy still depends on collecting live searches, requests, bookings, availability observations, and session outcomes, then monitoring drift and retraining.`
- `(android/ + ios/) - Native release artifacts cannot be built on this Mac yet: Flutter reports no Android SDK, incomplete Xcode, and no CocoaPods. Release signing, restricted Maps keys, and device builds remain environment/setup work.`
- `(.github/workflows/ci.yml) - CI enforces fatal Python checks, migrations, tests, Flutter analysis/tests, and a web build, but it does not build signed Android/iOS artifacts or run device tests.`
- `(.ruff configuration) - Full Ruff still reports pre-existing non-fatal style findings (mainly import ordering, line length, and framework call-site rules). The fatal syntax/name-error subset is clean, but the codebase is not style-clean.`
- `(test/ + backend/tests/) - Automated coverage is strong for current contracts (133 ML tests and 6 backend integration tests), but there is no real-device test, payment-provider sandbox test, FCM delivery test, or charger/OCPP integration test.`

## Verified fixed from the original error list

- `(database/models/*.py + alembic/versions/*) - ORM table names, fields, foreign keys, and the operational-integrity migration now align; `alembic check` passes with one head.`
- `(database/models/booking.py) - Duplicate `hold_expires_at` declaration removed.`
- `(docker-compose.yml + backend/Dockerfile + .dockerignore) - Reproducible PostGIS, Redis, migration, API, and ARQ worker stack added; Docker context reduced to runtime files and API image builds successfully.`
- `(docker-compose.yml + .env.example + backend/.env.example) - Local CORS defaults now allow both localhost and 127.0.0.1 web origins; LAN phone web testing still requires explicitly adding the Mac's IP origin.`
- `(backend/app/api/v1/payments.py + backend/app/services/booking.py) - Server-side price/ownership checks, payment verification, commits, idempotency, and enqueue-before-commit hold handling are implemented.`
- `(backend/app/worker.py) - Expiry processing uses the 10-minute hold policy and writes booking audit events.`
- `(backend/app/api/v1/booking.py + businesses.py + analytics.py) - Owner-scoped bookings, business ownership checks, live owner dashboard data, charger/port mutations, and availability persistence are wired to PostgreSQL.`
- `(backend/app/services/recommendation.py) - Vehicle ownership, connector compatibility, normalized reliability, and configured price fallback are enforced.`
- `(backend/app/api/v1/session.py) - Authenticated session list/get/rating endpoints and persistent issue flags are available.`
- `(backend/app/api/v1/ws.py + backend/app/main.py) - WebSocket pong handling, Redis `aclose()`, and a real DB/Redis/ML readiness check are implemented.`
- `(lib/core/auth/ + lib/core/network/ + lib/core/providers/) - Secure token restore/refresh, live booking cancellation, server-computed availability slots, and persisted owner actions are connected.`
- `(android/ + ios/ + web/) - VoltEZ package/label, build-time Maps key injection, debug-only Android cleartext networking, iOS local-network allowance, and web metadata are configured.`
- `(.github/workflows/ci.yml + scripts/smoke_test.py) - CI gates and smoke probes now target the actual `/health/live`, `/health/ready`, `/version`, and `/api/v1/openapi.json` contracts.`

## Verification performed on this branch

- `python -m compileall -q backend database src scripts` — passed.
- `ruff check --select E9,F63,F7,F82 backend database src scripts tests` — passed.
- `pytest -q tests` — **133 passed**.
- Backend integration suite with local PostGIS/Redis — **6 passed**.
- `alembic upgrade head` and `alembic check` — passed in the isolated Compose database.
- `flutter analyze` — **No issues found**.
- `flutter test` — **4 passed**.
- `flutter build web --release` — passed.
- Isolated Compose stack — PostGIS/Redis healthy, migration exited 0, API and worker running, `/health/ready` returned `{"database":true,"redis":true,"ml":true}`.

## Honest readiness verdict

The branch is deployment-ready for the verified **development/staging** path:
the API, database migrations, Redis worker, ML artifacts, live Flutter web
bundle, driver booking flow, and owner persistence are connected and tested.

It is **not yet a fully production charging network** until real Razorpay/Maps
credentials, HTTPS/WSS, FCM, a tariff source, charger telemetry, native SDKs,
release signing, and live-data ML monitoring are supplied. Those are explicit
external/integration prerequisites—not hidden code failures.
