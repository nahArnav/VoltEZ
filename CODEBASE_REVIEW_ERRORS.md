# VoltEZ Static Codebase Review — Confirmed Errors and Conflicts

Reviewed `main` at commit `a8e373680b33b9690958ffb0f9991285ce36af70` on 2026-08-26 after updating the local branch to the latest `origin/main`.

Scope: static inspection of the FastAPI backend, PostgreSQL/PostGIS models and Alembic migrations, ML artifacts and serving integration, Flutter client contracts, tests, scripts, and documentation. The application was **not started or exercised** for this review. No source code was changed; this report is the only modified file.

Required entry format: `(Filename) - (Error in it)`.

## P0 — Import and migration blockers

- `(database/base.py) - Imports seven model modules that are absent from database/models: booking_event, context_event, ml_feature_snapshot, ml_model_registry, ml_simulation_run, analytics_demand_bucket, and analytics_availability_observation. Any code path importing the canonical SQLAlchemy metadata is therefore broken.`
- `(backend/app/services/booking.py) - Imports database.models.booking_event, but that file and ORM class do not exist.`
- `(backend/app/services/session.py) - Imports database.models.booking_event, but that file and ORM class do not exist.`
- `(backend/scripts/seed_demo.py) - Imports the deleted app.models package and uses the obsolete backend-local model layout, so it is incompatible with the merged database package.`
- `(alembic/versions/314159265358_missing_tables.py) - Branches directly from ffc96748caa8 while the existing migration chain continues from that revision through ad409efaabba to 27e2cea710ae; the repository therefore has two Alembic heads and an ambiguous normal upgrade target.`
- `(alembic/versions/314159265358_missing_tables.py) - downgrade() is empty even though upgrade() creates multiple tables, so the migration is not reversible.`
- `(alembic/versions/314159265358_missing_tables.py) - Creates booking_events without an ORM model, gives booking_id no foreign key to app.bookings, and uses an integer primary key while backend/app/schemas/booking_event.py declares a UUID response ID.`
- `(alembic/versions/314159265358_missing_tables.py) - Creates context, analytics, feature-snapshot, registry, and simulation tables whose corresponding modules are imported by database/base.py but are missing from database/models.`

## P0 — Backend/database contract failures

- `(backend/app/services/booking.py) - Adds hold_expires_at to Booking construction, but database/models/booking.py and the canonical migrations define no such column; creating a held booking passes an invalid ORM keyword.`
- `(backend/app/services/trust.py) - Constructs ChargerStatusEvent without the non-null source, confidence, and observed_at columns required by database/models/charger_status_event.py, while burying some of those values inside details instead.`
- `(backend/app/schemas/charger_status_event.py) - Omits port_id, source, confidence, and observed_at and instead exposes the older error_code/details shape, so the API contract does not match the current ORM or Model 2 data requirements.`
- `(backend/app/services/fcm.py) - Constructs NotificationCreate with payload, but the schema has no payload field and requires title, message, and data; notification persistence cannot validate.`
- `(backend/app/services/fcm.py) - Creates a notification through a repository that only flushes, then never commits the transaction; even after correcting the schema payload, the notification is not guaranteed to persist.`
- `(backend/app/api/v1/vehicles.py) - Passes connector_type_ids from the request directly into Vehicle(**data), but Vehicle has no connector_type_ids column; connector compatibility must be written through vehicle_connectors.`
- `(backend/app/api/v1/vehicles.py) - Returns Vehicle ORM objects to a response schema requiring connector_type_ids even though the ORM exposes connector_types, so response serialization cannot produce the declared field without an explicit mapper.`
- `(backend/app/services/booking.py) - Commits a held booking before enqueueing its expiry job; if queueing fails, the Redis lock is removed but the committed HELD booking remains without an expiry job.`
- `(backend/app/api/v1/ws.py) - Calls websocket.accept() and then invokes ConnectionManager.connect(), which accepts the same socket again; a WebSocket connection is accepted twice.`

## P1 — Authorization, ownership, and payment correctness

- `(backend/app/api/v1/businesses.py) - BusinessUpdate accepts latitude and longitude, but the generic repository only updates real ORM attributes; coordinate changes are silently ignored instead of rebuilding the PostGIS location.`
- `(backend/app/repositories/business.py) - Annotates owner_id as int even though users and businesses use UUID identifiers.`
- `(backend/app/api/v1/chargers.py) - Charger creation checks that the caller has an owner role but does not verify that business_id belongs to that owner, allowing a business owner to attach a charger to another owner's business.`
- `(backend/app/api/v1/availability.py) - Availability mutation endpoints role-check owners but do not verify ownership of the selected charger port/window, allowing one owner to alter another owner's schedule.`
- `(backend/app/api/v1/payments.py) - Accepts amount and booking_id from the client without verifying booking ownership or recalculating the amount from a server-side quote, allowing price and ownership tampering.`
- `(backend/app/api/v1/payments.py) - Creates a payment through a repository that flushes but does not commit, and the route does not commit the transaction; the pending payment can be lost when the request session closes.`
- `(backend/app/api/v1/auth.py) - Refresh-token handling catches JWTError but not UUID conversion errors; a signed token with a malformed subject can reach an unhandled ValueError instead of a controlled authentication response.`
- `(backend/app/api/v1/ws.py) - Places the bearer token in the WebSocket query string, exposing credentials to browser history, proxy logs, and access logs.`

## P0 — ML serving is not connected to the published models

- `(backend/app/main.py) - Calculates the repository root with four parent traversals from backend/app/main.py; this resolves one directory above the repository, so the demand and availability artifact paths point outside models/.`
- `(backend/app/main.py) - Loads model.joblib files with raw joblib.load and stores their dictionary payloads as models. The demand artifact is a dictionary containing model/features/target_spec, and the availability artifact is a dictionary containing base_model/calibrator/feature_spec/thresholds; neither dictionary implements predict or predict_proba.`
- `(backend/app/ml/adapters.py) - Calls model.predict() and model.predict_proba() on the raw artifact dictionaries loaded by backend/app/main.py, so both published model adapters use an invalid object interface.`
- `(backend/app/ml/adapters.py) - Bypasses DemandPredictor.from_artifact and AvailabilityPredictor.from_artifact, losing artifact-hash checks, feature-contract validation, calibration, class thresholds, and the availability model's unknown/fallback policy.`
- `(backend/app/api/v1/recommendations.py) - Does not pass request.app.state.availability_model into the recommendation service, so Model 2 is never used by the recommendation endpoint even if loading is repaired.`
- `(backend/app/services/ml_features.py) - Builds mostly hard-coded median/static feature values and does not derive features from the requested zone, charger, port, database history, or prediction time; different entities can receive effectively identical predictions.`
- `(backend/app/ml/adapters.py) - Treats Model 2's probability of unavailability as wait_minutes = probability * 60. A classification probability is not an estimate of queue duration, so this output is scientifically invalid.`
- `(backend/app/api/v1/analytics.py) - Sends the raw demand artifact dictionary into the adapter that expects a predictor object, so the published Demand Forecasting model cannot be called through this endpoint.`
- `(backend/app/api/v1/health.py) - Reports status as ready regardless of whether ml_ready is false, allowing orchestration to route traffic to an API whose ML artifacts are unavailable.`
- `(backend/app/services/recommendation.py) - Scores reliability_score, stored on a 0–100 scale, as 50 * reliability_score while the base score is 1000; reliability alone can contribute 5000 points and dominate distance, wait, and price.`
- `(backend/app/services/recommendation.py) - Does not filter charger ports against the vehicle's connector types before ranking, so incompatible chargers can be recommended.`
- `(backend/app/services/recommendation.py) - Uses a separate simplified rolling/drag calculation instead of the repository's route-energy module and ignores drivetrain efficiency, elevation, auxiliary load, regenerative braking, reserve uncertainty, and confidence bounds.`
- `(backend/app/services/recommendation.py) - Sets reachable_km to the trip distance when reachable and zero otherwise, although the response field is described as the distance the vehicle can travel; the returned value has the wrong meaning.`
- `(backend/app/services/recommendation.py) - Uses a fixed ₹15/kWh estimate instead of tariff records, so recommendation cost is disconnected from database pricing.`
- `(backend/app/api/v1/chargers.py) - Nearby searches create a search event, but the recommendation service calls the nearby service directly and bypasses that route; the principal recommendation flow therefore does not record the search signal used by Model 1.`
- `(backend/app/) - No code creates ChargerSearchResult records, so ranks, impressions, selections, and unserved-result telemetry required for demand learning are never collected.`
- `(models/) - Contains deployable bundles for Demand Forecasting and Charger Availability only; Waiting-Time and Charger Reliability have no committed deployment bundles, so the backend cannot legitimately claim four deployed core models.`

## P1 — Analytics/schema contract gaps

- `(alembic/versions/314159265358_missing_tables.py) - Defines demand_buckets with only zone_id, time_bucket, and demand_score, omitting the search, request, booking, session, unserved, occupancy, and supply histories required by the documented demand-training contract.`
- `(alembic/versions/314159265358_missing_tables.py) - Defines availability_observations as a boolean is_available value, so it cannot represent the required available/unavailable/unknown label or store label source, confidence, booking state, port state, prediction origin, and arrival time.`
- `(database/models/charger_status_event.py) - port_id has no foreign-key constraint to charger_ports, allowing orphaned port-status evidence.`
- `(alembic/versions/314159265358_missing_tables.py) - Places analytics and ML operational tables in the app schema rather than the documented analytics and ml_lab schemas, creating drift between the schema design, ML pipeline, and migration implementation.`

## P0 — Flutter/FastAPI API conflicts

- `(lib/providers/auth_providers.dart) - Sends login credentials as JSON email/password, while FastAPI's OAuth2PasswordRequestForm endpoint requires form-encoded username/password.`
- `(lib/providers/auth_providers.dart) - Sends display_name during registration and profile updates, while the backend requires/returns name; registration also treats the user-only response as though authentication tokens were returned.`
- `(lib/providers/business_provider.dart) - Calls nonexistent /businesses/me, /businesses/me/chargers, /businesses/me/analytics/revenue, pricing recommendation, charger-status, and copilot endpoints.`
- `(lib/providers/business_provider.dart) - Business onboarding omits required zone_id and sends address instead of address_text; charger onboarding omits required charger_type, power_kw, latitude, and longitude and sends an unsupported ports object.`
- `(lib/services/business_api.dart) - Uses /businesses/me-style routes and a dated-slot availability payload, while the backend mounts ID-based business routes and models weekly day_of_week/start_local_time/end_local_time/is_unavailable windows.`
- `(lib/services/recommendation_services.dart) - Uses the placeholder https://api.yourdomain.com/v1, calls an unauthenticated GET /recommendations, and expects a raw list; the backend exposes an authenticated POST /api/v1/recommendations/ requiring location, vehicle, and state-of-charge and returns a wrapped response.`
- `(lib/services/profile_services.dart) - Uses a placeholder base URL, sends no authorization header, and calls /user/profile, /user/preferences, and /auth/logout routes that the backend does not expose.`
- `(lib/services/copilot_service.dart) - Uses a placeholder base URL without authentication and calls a copilot route absent from the FastAPI router.`
- `(lib/routes/app_router.dart) - Instantiates BusinessApi with https://api.yourdomain.com and an empty token, then defaults directly to /dashboard without an authentication redirect/guard.`
- `(lib/screens/business/charger_management_screen.dart) - Contains a hard-coded placeholder API URL instead of the configured authenticated API client.`
- `(lib/screens/business/dashboard_screen.dart) - Contains a hard-coded placeholder API URL instead of the configured authenticated API client.`
- `(lib/screens/business/port_details_screen.dart) - Contains a hard-coded placeholder API URL instead of the configured authenticated API client.`
- `(lib/models/charger.dart) - Expects power and reliability fields, while the backend returns power_kw and reliability_score.`
- `(lib/models/port.dart) - Expects name and status, while the backend returns connector_type_id, port_number, max_power_kw, and is_active.`
- `(lib/models/business.dart) - Expects business_name, verification, and address, while the backend returns name, verification_status, and address_text.`
- `(lib/models/availability_slot.dart) - Expects dated times, price_override, is_active, and repeat_weekly, which do not match the backend's weekly availability-window contract.`
- `(lib/models/booking.dart) - Expects vehicle/slot/amount-oriented fields that do not match BookingResponse's user_id, charger_port_id, start_at, end_at, and status contract.`
- `(lib/models/recommendation.dart) - Does not match either the backend RecommendationResponse or its nested recommendation item schema.`
- `(lib/services/) - Implements several disconnected HTTP clients with conflicting base URLs, authentication handling, endpoint names, and response models, so the Flutter application has no single valid backend contract.`

## P1 — Tests, quality gates, scripts, and documentation

- `(backend/requirements-test.txt) - Pins httpx==0.27.0 while backend/requirements.txt pins httpx==0.28.1; installing both declared dependency sets together is unsatisfiable.`
- `(backend/tests/integration/test_auth.py) - Uses uppercase role values even though the current API and database accept lowercase driver/owner/admin roles.`
- `(backend/tests/integration/test_booking_concurrency.py) - Imports the deleted app.models package and uses obsolete booking/model fields.`
- `(backend/tests/integration/test_booking_flow.py) - Sends business, charger, and booking payloads that no longer match current Pydantic schemas or ORM-required fields.`
- `(backend/tests/integration/test_vehicles.py) - Sends connector_types rather than connector_type_ids and omits required vehicle_class.`
- `(backend/tests/integration/test_recommendations.py) - Builds fixtures and requests against obsolete vehicle/connector and recommendation contracts rather than the current API.`
- `(pyproject.toml) - Configures pytest testpaths as tests only, excluding backend/tests from the repository's default test command.`
- `(scripts/smoke_test.py) - Probes /api/v1/health, but that route is not mounted by the current application router.`
- `(backend/scripts/seed_demo.py) - Uses obsolete model fields and package imports, so it cannot seed the canonical schema.`
- `(backend/, database/, alembic/) - Static Ruff analysis reports 831 findings on the reviewed commit, so the merged code does not satisfy the repository's configured lint gate.`
- `(.github/workflows/) - No CI workflow is present to detect duplicate migration heads, validate backend/Flutter API contracts, run backend and ML checks, or prevent another incompatible merge.`
- `(README.md) - Still describes ML-Final as the current branch even though the reviewed integration branch is main.`
- `(docs/api-contract.md) - Documents routes and payloads that diverge from both the mounted FastAPI routes and the Flutter calls, including booking, port, payment, ML, and recommendation flows.`
- `(docs/backend_fastapi_handoff.md) - Describes backend/ML wiring and service paths that are not present in the merged implementation.`
- `(lib/screens/business/intelligence/intelligence_screen.dart) - File is empty, leaving the advertised intelligence screen unimplemented.`
- `(lib/screens/chargers/chargers_screen.dart) - File is empty, leaving that charger screen unimplemented.`
- `(lib/widgets/stat_card.dart) - File is empty, leaving the shared widget unimplemented.`

## Bottom line

The merge has no unresolved Git conflict markers in the reviewed tracked files, but the codebase is **not integration-ready**. The immediate blockers are the missing ORM modules imported by `database/base.py`, the split Alembic history, invalid backend-to-model artifact loading, and the Flutter/backend API mismatch. Models 1 and 2 remain useful published artifacts, but the current FastAPI integration does not serve them correctly. Fix P0 items before attempting end-to-end deployment; then repair P1 correctness, security, telemetry, and quality-gate issues.
