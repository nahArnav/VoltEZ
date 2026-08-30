# VoltEZ final-frontend Readiness Review (historical)

> **Superseded report.** This snapshot was produced before the current
> integration work and intentionally records defects that have since been
> addressed. For the current branch status, read
> [`FINAL_FRONTEND_VERIFIED_ERRORS.md`](FINAL_FRONTEND_VERIFIED_ERRORS.md) and
> [`DEPLOYMENT_AND_PHONE_TESTING.md`](DEPLOYMENT_AND_PHONE_TESTING.md).

Reviewed branch: `origin/final-frontend`

Reviewed commit: `07df2fc58bfde326e7b051edecc1cc31ed340482`

Verdict: **not ready to run as a complete integrated application yet**.

Scope: static review of the Flutter frontend, FastAPI backend, database models, Alembic migrations, ML model serving integration, docs, and environment setup. The app was not launched. Python syntax-only compilation passed for `backend`, `database`, `src`, and `scripts`, but this only proves there are no Python parse errors. It does not prove import, database, API, ML, or Flutter readiness.

Requested format: `(Filename) - (Error in it)`.

## P0 - Branch and environment blockers

- `(local environment) - Neither flutter nor dart is available on PATH in this Codex environment, and /Applications/flutter/bin/flutter does not exist, while android/local.properties points flutter.sdk to /Applications/flutter. The Flutter app cannot be analyzed or run from this environment until the SDK path is fixed.`
- `(final-frontend branch) - No unresolved Git conflict markers were found, but the branch is checked as a detached worktree from origin/final-frontend rather than a local tracking branch. This is fine for review, but not ideal for direct development until a local branch is created.`
- `(.github/workflows/) - No CI workflow exists to validate Flutter analysis/build, backend imports, Alembic heads, Python tests, or frontend-backend API drift before merging.`

## P0 - Backend import and migration blockers

- `(database/base.py) - Imports missing modules: database.models.booking_event, database.models.context_event, database.models.ml_feature_snapshot, database.models.ml_model_registry, database.models.ml_simulation_run, database.models.analytics_demand_bucket, and database.models.analytics_availability_observation. Any backend path that imports the canonical SQLAlchemy metadata will fail.`
- `(backend/app/services/booking.py) - Imports database.models.booking_event, but database/models/booking_event.py does not exist.`
- `(backend/app/services/session.py) - Imports database.models.booking_event, but database/models/booking_event.py does not exist.`
- `(backend/scripts/seed_demo.py) - Imports the deleted app.models package and uses obsolete model fields, so the demo seeder is not compatible with the current database package.`
- `(alembic/versions/314159265358_missing_tables.py) - Creates a second migration branch from ffc96748caa8 while the existing migration chain continues to 27e2cea710ae. The repository has split Alembic history and needs a merge revision before normal upgrades are safe.`
- `(alembic/versions/314159265358_missing_tables.py) - downgrade() is empty despite creating multiple tables, making the migration non-reversible.`
- `(alembic/versions/314159265358_missing_tables.py) - Creates booking_events without a matching ORM model, gives booking_id no foreign key to app.bookings, and uses an integer id while backend/app/schemas/booking_event.py declares a UUID id.`
- `(alembic/versions/314159265358_missing_tables.py) - Creates analytics and ML support tables whose ORM files are imported by database/base.py but are absent from database/models.`

## P0 - Backend database and API contract errors

- `(backend/app/services/booking.py) - Adds hold_expires_at while constructing Booking, but database/models/booking.py and the current migrations do not define a hold_expires_at column.`
- `(backend/app/services/booking.py) - Commits a held booking before enqueueing the expiry job. If queueing fails, the Redis lock is removed but the HELD booking remains in the database without expiry handling.`
- `(backend/app/services/trust.py) - Creates ChargerStatusEvent without required source, confidence, and observed_at fields, while storing some of that information inside details instead of actual columns.`
- `(backend/app/schemas/charger_status_event.py) - Exposes the old error_code/details API shape and omits port_id, source, confidence, and observed_at, so it does not match the current ORM or Model 2 feature contract.`
- `(backend/app/services/fcm.py) - Builds NotificationCreate with payload, but backend/app/schemas/notification.py requires title, message, data, type, and status and has no payload field.`
- `(backend/app/services/fcm.py) - Creates notifications through a repository that flushes but does not commit; notification writes can be lost at request end.`
- `(backend/app/api/v1/vehicles.py) - Passes connector_type_ids directly into Vehicle(**data), but Vehicle has no connector_type_ids column. The code must create rows in vehicle_connectors instead.`
- `(backend/app/api/v1/vehicles.py) - Returns a Vehicle ORM object to a schema requiring connector_type_ids, but the ORM exposes connector_types through a relationship. Response serialization cannot produce the declared field without mapping.`
- `(backend/app/api/v1/recommendations.py) - Uses require_role(UserRole.OWNER.ADMIN), which is invalid enum chaining and should be separate role arguments.`
- `(backend/app/api/v1/ws.py) - Accepts the same WebSocket twice: ws.py calls websocket.accept(), and ConnectionManager.connect() accepts again.`

## P1 - Backend security and business logic gaps

- `(backend/app/api/v1/chargers.py) - Charger creation checks role only; it does not verify that the business_id belongs to the current owner.`
- `(backend/app/api/v1/availability.py) - Availability create/update/delete endpoints role-check owners but do not verify ownership of the charger port or window being changed.`
- `(backend/app/api/v1/payments.py) - Accepts amount and booking_id directly from the client without checking booking ownership or recalculating the amount from the server-side booking quote.`
- `(backend/app/api/v1/payments.py) - Creates a pending Payment through a repository that flushes but does not commit, and the route does not commit the transaction.`
- `(backend/app/api/v1/auth.py) - Refresh-token handling catches JWTError but not malformed UUID subjects, so some invalid refresh tokens can produce an unhandled server error instead of a controlled 401.`
- `(backend/app/api/v1/ws.py) - Puts the bearer token in the WebSocket query string, which can leak through browser history, logs, and proxies.`

## P0 - Flutter app integration blockers

- `(lib/core/network/api_service.dart) - Hardcodes http://localhost:3000/api/v1 even though the FastAPI backend and AppConfig use port 8000 for local development. The active AuthProvider uses this hardcoded client.`
- `(lib/core/network/api_service.dart) - Sends login as JSON email/password, but backend/app/api/v1/auth.py uses OAuth2PasswordRequestForm and expects form-encoded username/password.`
- `(lib/core/network/api_service.dart) - Registers with default role DRIVER, but backend/app/schemas/user.py only accepts lowercase driver or owner.`
- `(lib/core/network/api_service.dart) - Calls POST /routes/recommendations, but the backend mounts POST /recommendations/.`
- `(lib/core/network/api_service.dart) - Sends route recommendation payload with origin, destination, vehicle, current_soc, reserve_soc, and preference, while backend/app/schemas/recommendation.py expects latitude, longitude, radius_meters, vehicle_id, current_soc, target_soc, reserve_soc, and preferences.`
- `(lib/core/network/api_service.dart) - Calls POST /bookings/{id}/confirm, but backend/app/api/v1/booking.py exposes no confirm endpoint.`
- `(lib/core/network/api_service.dart) - Calls GET /bookings and GET /bookings/{id}, but backend/app/api/v1/booking.py exposes only POST /bookings/ and POST /bookings/{booking_id}/cancel.`
- `(lib/core/network/api_service.dart) - Calls POST /sessions/{id}/report-issue, but backend/app/api/v1/session.py exposes only check-in, start, and complete.`
- `(lib/core/network/api_service.dart) - Calls GET /businesses/me, but backend/app/api/v1/businesses.py exposes list/create/get/update/delete by explicit business ID only.`
- `(lib/core/network/api_service.dart) - Calls GET /chargers with business_id, PATCH /chargers/{id}, and DELETE /chargers/{id}, but backend/app/api/v1/charger.py only exposes create, nearby, and report-issue.`
- `(lib/core/network/api_service.dart) - Calls /ports/{id}/availability, but backend/app/api/v1/availability.py uses /availability/port/{port_id} and /availability/.`
- `(lib/core/network/session_websocket.dart) - Connects to /sessions/{sessionId}/stream, but the backend WebSocket route is /api/v1/ws/{user_id}?token=... and is not session-scoped.`
- `(lib/shared/models/models.dart) - Models User, Vehicle, Charger, Booking, Payment, AvailabilityWindow, Review, and Session ids as int, while the backend schemas use UUIDs. Real UUIDs will parse to 0 or be lost.`
- `(lib/shared/models/models.dart) - ChargerPort.fromJson expects connector_type and status, while backend/app/schemas/charger_port.py returns connector_type_id, port_number, max_power_kw, and is_active.`
- `(lib/shared/models/models.dart) - AvailabilityWindow expects start_at/end_at/source/price_override/status/is_recurring, while backend/app/schemas/availability_window.py uses day_of_week/start_local_time/end_local_time/is_unavailable.`
- `(lib/shared/models/models.dart) - Notification expects payload, but backend notification schema uses title, message, and data.`

## P1 - Flutter code organization and live-readiness issues

- `(lib/core/auth/auth_provider.dart) - Login and signup call the real backend, but the LoginScreen bypasses this provider logic with demoLogin, so the visible auth flow is not proving real backend auth.`
- `(lib/features/auth/login_screen.dart) - _submit() always calls demoLogin and never calls AuthProvider.login or AuthProvider.signup. Real authentication is not connected to the primary login UI.`
- `(lib/core/providers/charger_discovery_provider.dart) - Loads hardcoded mock chargers instead of calling ApiService.getNearbyChargers. The driver map is not connected to real charger search.`
- `(lib/core/providers/booking_provider.dart) - Defaults to MockBookingApi, while LiveBookingApi methods all throw UnimplementedError. Real slot holding, payment-order creation, and booking history are not connected.`
- `(lib/core/network/booking_api.dart) - LiveBookingApi is entirely unimplemented and throws UnimplementedError for availability, hold, payment, verification, and history.`
- `(lib/core/providers/route_planner_provider.dart) - Defaults to MockRouteRecommendationApi, while LiveRouteRecommendationApi throws UnimplementedError. Route recommendations are not connected to the backend or ML models.`
- `(lib/core/network/route_recommendation_api.dart) - LiveRouteRecommendationApi is not connected and explicitly throws UnimplementedError.`
- `(lib/core/providers/session_provider.dart) - Defaults to MockSessionApi and MockSessionWebSocket, so charging sessions are simulated rather than connected to backend session endpoints.`
- `(lib/core/network/session_api.dart) - LiveSessionApi is entirely unimplemented and throws UnimplementedError for check-in, status, end, rating, and history.`
- `(lib/core/network/business_api.dart) - Only MockBusinessApi exists. Business dashboard data is not connected to real backend business, charger, booking, analytics, or pricing endpoints.`
- `(lib/features/business/dashboard/dashboard_screen.dart) - Business dashboard renders hardcoded charger, booking, revenue, and utilization data instead of calling a backend provider.`
- `(lib/core/routing/app_router.dart) - Routes /business/chargers, /business/availability, /business/bookings, /business/analytics, and /business/profile to placeholder screens even though feature files exist.`
- `(lib/providers/auth_providers.dart) - A second Riverpod auth implementation remains in the tree and still uses display_name, JSON login, and token expectations that do not match the FastAPI backend.`
- `(lib/providers/business_provider.dart) - A second Riverpod business implementation remains in the tree and calls nonexistent /businesses/me, /pricing/recommendations, /chargers/{id}/status, and copilot endpoints.`
- `(lib/services/profile_services.dart) - Uses placeholder https://api.yourdomain.com/v1, no auth header, and nonexistent /user/profile and /user/preferences endpoints.`
- `(lib/services/recommendation_services.dart) - Uses placeholder https://api.yourdomain.com/v1, unauthenticated GET /recommendations, and /recommendations/{id}/status, which do not match the backend.`
- `(lib/services/copilot_service.dart) - Uses placeholder https://api.yourdomain.com/v1 and calls /businesses/me/copilot-query, which the backend does not mount.`
- `(lib/screens/business/intelligence/intelligence_screen.dart) - File is empty.`
- `(lib/widgets/stat_card.dart) - File is empty.`

## P0 - ML integration blockers

- `(backend/app/main.py) - Calculates base_dir using four parent traversals from backend/app/main.py, which points one directory above the repository. The model paths therefore point outside the checked-out models directory.`
- `(backend/app/main.py) - Loads model.joblib artifacts with raw joblib.load and stores dictionary payloads in app.state. The demand artifact is not a direct predictor object, and the availability artifact is not a direct classifier object.`
- `(backend/app/ml/adapters.py) - Calls model.predict() and model.predict_proba() on the raw artifact payloads, so Model 1 and Model 2 serving will not work with the published bundles.`
- `(backend/app/ml/adapters.py) - Bypasses DemandPredictor.from_artifact and AvailabilityPredictor.from_artifact, losing feature-contract validation, calibration, thresholds, fallback policy, and artifact verification.`
- `(backend/app/services/ml_features.py) - Builds mostly hardcoded median feature values and ignores database history, current entity, target zone, port, charger state, and prediction time.`
- `(backend/app/ml/adapters.py) - Treats Model 2 unavailability probability as wait_minutes = probability * 60, which is not a valid waiting-time estimate.`
- `(backend/app/api/v1/recommendations.py) - Does not pass request.app.state.availability_model into recommendation_service.get_recommendations, so Model 2 is not used by the main recommendation endpoint even if model loading is fixed.`
- `(backend/app/services/recommendation.py) - Does not filter ports by the vehicle's connector compatibility before ranking.`
- `(backend/app/services/recommendation.py) - Uses a fixed 15 INR/kWh price instead of tariff/database pricing.`
- `(backend/app/services/recommendation.py) - Scores reliability_score as if its scale were 0 to 1, but backend charger reliability is 0 to 100. This can dominate ranking results.`
- `(models/) - Contains deployable bundles for demand and availability only. Waiting-time, reliability, and other support models are not deployed here.`

## P1 - Data, telemetry, and analytics gaps

- `(backend/app/api/v1/chargers.py) - Nearby charger search records ChargerSearchEvent, but the recommendation service bypasses that route and calls charger_service directly, so route-planning searches do not create demand telemetry.`
- `(backend/app/) - No backend path creates ChargerSearchResult rows, so ranking impressions, result counts, selected chargers, and unserved-result data are not collected.`
- `(alembic/versions/314159265358_missing_tables.py) - demand_buckets stores only zone_id, time_bucket, and demand_score, but the ML contract needs search_count, request_count, booking_count, session_count, unserved_count, occupancy_rate, and contextual features.`
- `(alembic/versions/314159265358_missing_tables.py) - availability_observations stores only a boolean is_available and cannot represent available/unavailable/unknown labels, label_source, confidence, booking state, port status, prediction origin, or target arrival time.`
- `(database/models/charger_status_event.py) - port_id has no foreign key to app.charger_ports, allowing orphaned port-status evidence.`

## P1 - Tests, docs, and stale contracts

- `(backend/requirements-test.txt) - Pins httpx==0.27.0 while backend/requirements.txt pins httpx==0.28.1. Installing both declared backend dependency files together is conflicting.`
- `(backend/tests/integration/test_auth.py) - Uses uppercase role values even though UserCreate accepts lowercase driver and owner.`
- `(backend/tests/integration/test_booking_concurrency.py) - Imports deleted app.models modules and uses obsolete booking fields.`
- `(backend/tests/integration/test_booking_flow.py) - Sends old business, charger, vehicle, and booking payloads that do not match current schemas.`
- `(backend/tests/integration/test_vehicles.py) - Sends connector_types and omits vehicle_class, while VehicleCreate requires connector_type_ids and vehicle_class.`
- `(backend/tests/integration/test_recommendations.py) - Uses obsolete vehicle and recommendation request shapes rather than backend/app/schemas/recommendation.py.`
- `(pyproject.toml) - Default pytest testpaths points to tests only, so backend/tests are excluded from the default root test command.`
- `(scripts/smoke_test.py) - Probes /api/v1/health, but the backend exposes /health/live and /health/ready outside the /api/v1 prefix.`
- `(docs/api-contract.md) - Documents /routes/recommendations and several booking/payment/port routes that do not match the mounted FastAPI router.`
- `(docs/frontend-api-mapping.md) - Claims several frontend methods map to backend endpoints that are not implemented or do not match the actual request/response schemas.`
- `(docs/backend_fastapi_handoff.md) - Describes ML routes and service paths that are not present in the merged backend.`

## Bottom line

The branch can probably show parts of the Flutter UI in demo/mock mode once Flutter is installed, but it is not ready to run as the real VoltEZ application. The main blockers are: missing backend ORM files, split Alembic migrations, broken backend-to-ML artifact loading, frontend calls to wrong/nonexistent endpoints, int-vs-UUID model mismatch, and live frontend APIs that still throw `UnimplementedError`.
