# VoltEZ `final-frontend` Verified Error Report

Reviewed branch: `final-frontend`

Reviewed local commit: `90a4df1`

Remote comparison: local is 3 commits ahead of `origin/final-frontend` and 0 commits behind. No pull was required.

Review date: 2026-08-26

This report records issues verified against the current local branch. The older `errors.md` and `FINAL_FRONTEND_READINESS_ERRORS.md` reports contain many defects that have already been fixed and are not repeated here.

Requested format: `(Filename) - (Error in it)`.

## P0 — Build and deployment blockers

- `(lib/screens/dashboard/ai_recommendations_screen.dart) - Flutter analysis fails because fetchRecommendations is called without five required parameters and updateStatus no longer exists.`
- `(lib/screens/profile/profile_screen.dart) - Flutter analysis fails because updateProfile receives removed email/businessName parameters and updatePreferences no longer exists.`
- `(alembic/versions/314159265358_missing_tables.py + database/models/*.py) - Alembic check detects substantial schema drift: ML/analytics ORM table names and fields do not match migrated tables, booking_events has incompatible id/types/columns, and context_events fields differ. A fresh deployment and the ORM do not share one canonical schema.`
- `(database/models/booking.py) - hold_expires_at is declared twice on the Booking ORM model.`
- `(docker-compose.yml) - The root deployment stack defines only PostgreSQL. It does not start Redis, the ARQ expiry worker, FastAPI, or the Flutter web build, so the application cannot be deployed as one reproducible stack.`
- `(.env.example + backend/.env.example) - Environment templates are incomplete and inconsistent with required Settings fields and production integrations. They do not provide one authoritative contract for PROJECT_NAME, SECRET_KEY, database, Redis, CORS, Razorpay, Maps, and public frontend URLs.`

## P0 — Payment and booking correctness/security

- `(backend/app/api/v1/payments.py) - create-order trusts amount and currency supplied by the client instead of verifying booking ownership and using a server-side quote, which permits price tampering.`
- `(backend/app/api/v1/payments.py + app/repositories/base.py) - Payment creation only flushes and never commits, so a successful response can still be rolled back at request teardown.`
- `(backend/app/api/v1/payments.py) - There is no authenticated client verification endpoint for Razorpay checkout signatures; only the asynchronous webhook exists.`
- `(lib/features/driver/payment/payment_screen.dart) - Uses the literal YOUR_RAZORPAY_KEY_ID instead of build-time configuration.`
- `(lib/core/network/razorpay_service.dart) - Web builds report a fabricated successful payment with a fake payment id. This can mislead users and must never exist in a production payment flow.`
- `(lib/core/network/booking_api.dart) - LiveBookingApi.verifyPayment always throws, so a genuine successful mobile Razorpay checkout cannot confirm the booking in the UI.`
- `(backend/app/api/v1/booking.py + backend/app/services/booking.py) - The HELD booking is committed before the expiry job is enqueued. If Redis/ARQ enqueueing fails, a persisted active hold remains without a scheduled expiry.`
- `(backend/app/worker.py) - The expiry worker updates the booking status but does not create a BookingEvent audit record and its documentation says 15 minutes while the actual hold is 10 minutes.`

## P0 — Owner/business experience is not integrated

- `(lib/core/routing/app_router.dart) - Business chargers, availability, bookings, analytics, and profile routes still render Coming soon placeholders.`
- `(lib/features/business/dashboard/dashboard_screen.dart) - Dashboard totals, chargers, bookings, utilization, analytics, and profile data are hardcoded rather than loaded from authenticated backend data.`
- `(lib/features/business/chargers/charger_management_screen.dart) - Charger records and Pause/Resume actions mutate an in-memory list and are not persisted.`
- `(lib/features/business/availability/availability_scheduler_screen.dart) - Availability windows and Save actions mutate local state only and are not stored in PostgreSQL.`
- `(backend/app/api/v1/booking.py) - Only a driver's own bookings can be listed. There is no owner-scoped booking view for bookings placed against the owner's ports.`
- `(backend/app/api/v1/analytics.py) - Business analytics checks the owner role but does not verify that the requested business belongs to the authenticated owner.`

## P1 — Recommendation and ML serving correctness

- `(backend/app/services/recommendation.py) - Selects the highest-power active port without filtering it against the vehicle's connector types, so incompatible chargers can be recommended.`
- `(backend/app/services/recommendation.py) - Uses a fixed INR 15/kWh value because there is no implemented tariff model/table, so displayed cost is not authoritative.`
- `(backend/app/services/recommendation.py) - Adds 50 * reliability_score while reliability_score is stored on a 0–100 scale; this can overwhelm every other ranking factor.`
- `(backend/app/services/ml_features.py) - Runtime features use calendar context but still lack sufficient persisted history/entity telemetry for real production distribution quality. The models can serve, but real-world quality requires live observation collection and retraining.`
- `(backend/app/api/v1/recommendations.py + backend/app/services/recommendation.py) - Route recommendations bypass search impression/result persistence, so searches, unserved demand, rankings shown, and selections are not fully captured for later model training.`

## P1 — Session and realtime gaps

- `(backend/app/api/v1/ws.py + lib/core/network/session_websocket.dart) - The access token is placed in the WebSocket query string, which can leak through proxy/access logs.`
- `(backend/app/api/v1/ws.py) - The server receives ping messages but never returns a pong, despite the frontend protocol documenting pong support.`
- `(backend/app/api/v1/session.py) - Session APIs support check-in/start/complete but provide no authenticated GET/status/history endpoints, forcing the frontend to reconstruct history from bookings and local state.`

## P1 — Mobile configuration blockers

- `(android/app/src/main/AndroidManifest.xml) - Google Maps uses YOUR_GOOGLE_MAPS_API_KEY and the application label/package configuration is still generic.`
- `(ios/Runner/AppDelegate.swift) - Google Maps uses YOUR_GOOGLE_MAPS_API_KEY instead of an injected build configuration value.`
- `(lib/core/network/api_service.dart + lib/main.dart) - Default API and WebSocket URLs point to 127.0.0.1. On a physical phone that address is the phone itself, so phone builds must inject the Mac LAN address or a deployed HTTPS/WSS endpoint.`
- `(ios/Runner/Info.plist + Android network policy) - A physical phone using a local HTTP backend needs explicit development network allowances; a production build must use HTTPS/WSS.`

## P1 — Tests, quality gates, and stale code

- `(backend/tests/integration/*.py) - All 6 backend integration tests fail. They use uppercase roles, deleted app.models imports, and obsolete request fields, so they do not validate the current API.`
- `(pyproject.toml) - Default pytest discovery includes only tests/ and excludes backend/tests/, allowing backend regressions to pass the default command.`
- `(test/) - Flutter has only two small widget-test files; there are no live API contract, auth persistence, booking lifecycle, owner workflow, or failure-state tests.`
- `(.github/workflows/) - No CI workflow enforces Python compilation/tests, Alembic consistency, Flutter analysis/tests, or production builds.`
- `(lib/screens/, lib/services/, lib/providers/, lib/widgets/) - A parallel legacy Flutter architecture remains alongside lib/core and lib/features. It contains broken contracts and placeholder services, causes analyzer failures, and makes it unclear which implementation is authoritative.`
- `(scripts/smoke_test.py) - The smoke test still probes /api/v1/health instead of /health/ready and does not validate auth, persistence, ML readiness, bookings, or owner operations.`
- `(backend/app/main.py) - Uses deprecated redis.close() instead of aclose(), producing warnings on every test lifespan.`

## Verified working before fixes

- Python syntax compilation passes for `backend`, `database`, `src`, and `scripts`.
- Alembic has one revision head (`20260826a005`).
- Both deployable ML artifacts load during backend startup.
- Flutter widget tests pass (4 tests).
- Core driver auth, charger discovery, route recommendation, availability, and booking-history adapters are connected to FastAPI.

## Honest readiness verdict

The current branch is demo-capable for part of the driver web flow, but it is not production ready. The highest-risk blockers are canonical database drift, unsafe/incomplete payments, non-persistent owner screens, stale backend tests, placeholder mobile secrets, and the absence of a reproducible deployment/CI pipeline.
