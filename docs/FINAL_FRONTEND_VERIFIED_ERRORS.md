# VoltEZ `final-frontend` current error and readiness report

Reviewed worktree: `final-frontend`
Review date: 2026-08-30
Review scope: static code, API/ML contracts, migrations, Flutter analysis, and
deployment documentation. No production services or phone build were started
as part of this review.

This report describes the current local worktree. It does not claim that the
local worktree matches GitHub: the last remote fetch was blocked by DNS, and
the current changes have not been committed or pushed.

## Confirmed current shortcomings and deployment blockers

- `(docker-compose.yml + backend)` - Compose provisions PostGIS and Redis only.
  It does not run Alembic, start Uvicorn, or start the ARQ worker. Run those
  processes explicitly or add equivalent services in the chosen deployment
  supervisor.
- `(backend/.env.example + deployment)` - Production still needs a real
  PostgreSQL/PostGIS instance, Redis, HTTPS/WSS, explicit CORS origins, secret
  management, backups, and logging/alerting.
- `(backend/app/services/fcm.py)` - Push notifications are not connected to a
  production FCM provider. Notifications are persisted and can use the in-app
  channel until credentials and device-token delivery are configured.
- `(backend/app/api/v1/session.py)` - Session energy/telemetry remains
  client-supplied/simulated. A real charger/OCPP/provider adapter is required
  before treating delivered energy as physical charging truth.
- `(payments)` - Stripe hosted Checkout is now the preferred path when
  `STRIPE_SECRET_KEY` is configured, with signed webhook and server-side
  session verification; Razorpay remains the fallback. A real Stripe/Razorpay
  account, webhook signing secret, return URLs, and phone smoke test are still
  deployment tasks.
- `(backend KYC endpoints)` - KYC values are validated/masked and persisted,
  but there is no external identity provider or human/admin review workflow.
- `(location search)` - Charger registration, map search, and route search now
  use the backend's debounced India-constrained search. When
  `GOOGLE_MAPS_API_KEY` is configured it uses Places Autocomplete + Details for
  coordinate-backed suggestions; without that key it falls back to the
  India-constrained Nominatim adapter and native OS geocoding.
- `(backend/src/voltez_ml/route_energy + recommendation service)` - Model 5
  route-energy physics is packaged and tested, but the live recommendation
  endpoint still uses its bounded deterministic physics calculation; Model 5
  is not yet wired into production inference.
- `(backend/models/*)` - Demand and availability artifacts are trained on
  synthetic Pune data. They are valid for integration/demo testing, not a
  substitute for live calibration; collect searches, requests, bookings,
  availability observations, and outcomes before making accuracy claims.
- `(android/ + ios/)` - Native release artifacts still require a complete
  Android SDK/Xcode/CocoaPods setup, release signing, and device testing on the
  target machine.
- `(tests/integration)` - The integration suite requires reachable PostGIS and
  Redis. It was not run in the current sandbox; the unit/contract suite passes
  with integration tests excluded.

## Verified in the current worktree

- `(backend/app/main.py)` - `/health/ready` now probes database and Redis with a
  bounded timeout and returns HTTP 503 unless both dependencies and both core
  ML bundles (demand and availability) are ready. It never reports a degraded
  instance as healthy.
- `(backend/app/services/pricing.py + booking/session/availability)` - Dynamic
  pricing is bounded and explainable. A quote is locked on booking hold and the
  final session amount uses delivered energy multiplied by that locked rate;
  the ₹50 hold is separate from the charging tariff.
- `(business charger registration UI)` - Registration no longer asks users to
  type latitude/longitude. A debounced native address search, suggestion
  selection, and current-device-location option provide coordinates and an
  address label.
- `(frontend onboarding catalogue)` - The EV selector includes major Indian
  cars, scooters, motorcycles, three-wheelers, and connector variants, with an
  `Other/Custom` escape hatch for vehicles outside the maintained catalogue.
- `(Flutter UI)` - The previously observed dialog, payment, onboarding, and
  route/recommendation overflow paths have bounded/scrollable layouts and
  normalized connector labels.
- `(ML integration)` - Model 1 demand and Model 2 availability are loaded once
  with SHA-256 verification and used by recommendation/analytics inference;
  every prediction is recorded for auditability. Heuristic fallbacks remain
  available when development artifacts are absent.
- `(notifications)` - Authenticated users can read and mark persisted
  notifications through `/users/me/notifications`; OS push delivery still needs
  FCM credentials and device-token registration.
- `(sponsor evidence)` - Concrete runtime/development usage, credential
  boundaries, fallbacks, and demo evidence are recorded in
  `docs/SPONSOR_INTEGRATION_PLAN.md`. Optional providers are intentionally not
  described as enabled until their credentials and evidence exist.
- `(backend/scripts/seed_demo.py)` - The deterministic demo seed is reconciled
  with the current ORM (UUID zone/connector references, normalized business
  hours and charger availability, current booking/session fields, and demand
  history). It imports cleanly and is safe for a fresh migrated development
  database; it still refuses to run when users already exist.

## Verification performed

- `backend/.venv/bin/ruff check app database tests` — passed.
- `backend/.venv/bin/python -m compileall -q app database` — passed.
- `backend/.venv/bin/alembic heads` — one head: `20260830a005`.
- Backend unit/contract suite excluding integration — **138 passed**.
- `/opt/homebrew/share/flutter/bin/cache/dart-sdk/bin/dart analyze frontend` —
  **No issues found**.
- `git diff --check` — passed.

## Honest readiness verdict

The local branch is in a strong development/staging state: the API contracts,
database migrations, core ML serving, dynamic tariff path, charger registration
UX, and Flutter static analysis are internally consistent.

It is not honestly “deployment ready” until the external prerequisites above
are supplied and verified against real PostGIS/Redis services, payment/KYC/
notification providers, telemetry, native release builds, and a phone smoke
test. No code change can manufacture those credentials or physical charger
truth.
