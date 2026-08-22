**  

VoltEZ

HACKATHON-WINNING BUILD PLAYBOOK

Step-by-step engineering guide for Web + Flutter Mobile + Backend + ML + Sponsor Integrations

  
  
  

Prepared as an execution manual: build order, ownership, schemas, APIs, ML, UI, testing, deployment, demo and judging strategy.  

1. # Read This Before You Build
    

This playbook is deliberately opinionated. The fastest way to lose a hackathon is to build ten disconnected features. The fastest way to impress technical judges is to show one coherent system whose product decisions, data model, concurrency handling, ML outputs and user experience all reinforce the same story.

  
  

## What the source deck already establishes

- The problem is EV mobility intelligence: smarter charging infrastructure and route optimization.
    
- VoltEZ focuses on underutilized chargers in malls, offices, apartments and other private/commercial spaces.
    
- Drivers need discovery, booking and more trustworthy availability; businesses need utilization and revenue.
    
- The differentiator is off-peak revenue intelligence: charging is used to bring customers to a business during slow hours.
    
- The proposed system includes demand forecasting, congestion/wait estimation, route optimization, dynamic/pricing recommendations, lightweight check-in/check-out and business analytics.
    

## Architecture decision

Use a modular monolith for the hackathon. One FastAPI backend is easier to ship, debug and demo than microservices. Keep strict internal boundaries so modules can later split if needed.

Next.js Web / Flutter Mobile

| REST/JSON

| FastAPI

+--------+ +

| | |

Auth Booking Intelligence

| | |

+---- Service Layer +

| PostgreSQL + PostGIS

| |

Redis Celery

| |

booking locks background jobs

|

Maps / Payment / OTP / Sponsor APIs / ML

  
  

1. # Product Scope: What You Build vs What You Pitch
    

  

|   |   |   |   |
|---|---|---|---|
|Tier|Must be real in demo|Can be simulated/seeded|Do not prioritize|
|P0|Auth; owner onboarding; charger listing; geospatial search; vehicle compatibility; booking state machine; slot locks; driver recommendation;<br><br>check-in/out; dashboard; deployed system|Seed charger inventory and usage history|Investment marketplace|

  
  
  

|   |   |   |   |
|---|---|---|---|
|P1|Demand forecast; wait estimate; off-peak recommendation; explainable ranking; reliability score; payments in sandbox; notifications|Synthetic historical demand if clearly labeled|Complex CPO interoperability|
|P2|Tavily/Gemini/Lyzr intelligence; n8n automations; sponsor-specific polish; analytics exports|VAHAN/DISCOM data via mock adapters if access unavailable|Production settlement, roaming protocols, full IoT hardware|

  

## Success metrics judges can understand

- Recommendation latency: target < 1.5 s with cached candidates; show measured demo value.
    
- No double-booking under concurrent requests: demonstrate with an automated test.
    
- Nearby search uses PostGIS spatial index rather than scanning all chargers.
    
- Every recommendation explains compatibility, detour, predicted wait, charge time, estimated cost and reliability.
    
- ML models have a baseline, validation metric and fallback rule. Never present an unvalidated model as magic.
    
- Owner remains in control: AI recommends availability/pricing; owner approves.
    
- System degrades gracefully when Maps, AI or sponsor APIs are unavailable.
    

  
  

2. # Phase 0 - Repository, Environments and Team Contract
    

Do this before feature coding. It prevents merge chaos in the final hours.

1. Create a GitHub organization/repository named voltez. Use a monorepo unless teams are already operating independently.
    
2. Create folders: apps/web, apps/mobile, services/api, ml, infra, docs, scripts.
    
3. Protect main. Require pull requests and at least one teammate review for backend/database changes.
    
4. Create branches by vertical slice, not by person: feat/booking-flow, feat/driver-map, feat/demand-model.
    
5. Add .env.example files for every app. Never commit secrets.
    
6. Define local ports: web 3000, API 8000, PostgreSQL 5432, Redis 6379.
    
7. Add Docker Compose for PostgreSQL + PostGIS + Redis. Keep frontend runtimes local for fast hot reload.
    
8. Add pre-commit checks: Python formatting/linting, TypeScript lint, Flutter analyze.
    
9. Create a shared docs/api-contract.md and docs/business-rules.md. Changes to request/response shapes must update these files.
    
10. Create a demo seed script from day one. A hackathon demo should be reproducible from a clean database.
    

voltez/ apps/

web/ # Next.js

mobile/ # Flutter services/

api/ # FastAPI modular monolith ml/

notebooks/ training/ artifacts/ evaluation/

infra/

docker-compose.yml render/

docs/

architecture.md api-contract.md business-rules.md demo-script.md  

scripts/ seed_demo.py smoke_test.py

  
  

3. # Phase 1 - Build the Backend Foundation First
    

4. ## Create the FastAPI skeleton
    

5. Create a Python virtual environment and install FastAPI, Uvicorn, Pydantic Settings, SQLAlchemy 2, psycopg, GeoAlchemy2, Alembic, Redis client, Celery, httpx, python-jose or equivalent JWT library, passlib/argon2, pytest and pytest-asyncio.
    
6. Create app/main.py with application factory, CORS, exception handlers, request ID middleware and /api/v1/health.
    
7. Create app/core/config.py using environment-backed settings. Validate required production secrets at startup.
    
8. Create app/db/session.py with SQLAlchemy engine/session dependency. Keep sessions request-scoped.
    
9. Create app/api/v1/router.py and mount feature routers under /api/v1.
    
10. Add structured logging with request_id, user_id when authenticated, endpoint, status and latency.
    

services/api/app/ main.py

core/

config.py security.py errors.py logging.py

api/v1/ router.py auth.py users.py vehicles.py businesses.py chargers.py

availability.py bookings.py sessions.py recommendations.py payments.py analytics.py

models/ schemas/ repositories/ services/ integrations/ ml/

tasks/ db/

  

2. ## Database schema - build this before APIs
    

|   |   |   |
|---|---|---|
|Entity|Key fields|Why it exists|
|users|id, name, phone/email, password_hash, role, verification_status, created_at|Identity and RBAC|
|vehicles|user_id, make/model, battery_kwh, connector_types, max_ac_kw, max_dc_kw, estimated_range_km|Compatibility and route intelligence|

  
  
  

|   |   |   |
|---|---|---|
|businesses|owner_id, name, category, location, opening_hours, verification_status|Commercial host|
|chargers|business_id, name, point geography, power_kw, access_type, base_price, status, reliability_score|Physical charger|
|charger_ports|charger_id, connector_type, max_power_kw, status|Bookable connector/port|
|availability_windows|port_id, start_at, end_at, source, price_override, status|Owner-approved bookability|
|bookings|user_id, vehicle_id, port_id, start_at, end_at, status, hold_expires_at, quote snapshot|Reservation lifecycle|
|charging_sessions|booking_id, check_in_at, start_at, end_at, energy_kwh, final_amount, status|Actual charging event|
|payments|booking_id, provider_order_id, provider_payment_id, amount, status, verified_at|Server-side payment truth|
|charger_status_events|charger_id/port_id, status, source, confidence, observed_at|No-IoT trust model|
|reviews|session_id, rating, issue flags|Reliability signal|
|demand_history|zone/time bucket, demand_count, occupancy, contextual features|ML training|
|ml_predictions|entity_id, model_name/version, prediction_type, value, confidence, generated_at|Auditability|
|booking_events|booking_id, old_status, new_status, actor, metadata, created_at|Debugging/audit|
|notifications|user_id, type, payload, status, scheduled_at, sent_at|Async communication|

  

Use PostGIS geography(Point, 4326) for charger/business coordinates. Add GiST spatial indexes. Use UTC in storage and convert to local time in clients.

3. ## Migrations and seed data
    

4. Initialize Alembic and create migration 001_core_entities.
    
5. Enable PostGIS in the database migration or provisioning step.
    
6. Create indexes for charger location, booking port/time/status, availability port/time and prediction entity/time.
    
7. Write seed_demo.py that creates at least 3 businesses, 12 chargers, mixed connector types, 3 vehicles and 30 days of synthetic usage history.
    
8. Create one intentionally unreliable charger and one incompatible charger so the recommendation explanation is visible during demo.
    

  

9. # Phase 2 - Authentication, Roles and Onboarding
    

10. Implement DRIVER, OWNER/BUSINESS_ADMIN and ADMIN roles. Keep authorization in backend dependencies, never only in UI.
    
11. Registration creates an unverified user. OTP/email verification flips verification_status.
    
12. Login issues short-lived access token and refresh token. Rotate refresh tokens; revoke on logout.
    
13. Create GET /users/me and PATCH /users/me.
    
14. Driver onboarding requires at least one vehicle before personalized recommendations.
    
15. Owner onboarding creates a business profile, address/geocode, opening hours and verification status.  
    
16. For hackathon verification, allow admin/manual verification and expose an adapter interface for future VAHAN/business verification.
    

  

17. # Phase 3 - Charger Inventory, Ports, Availability and Trust
    

18. ## Owner charger onboarding
    

19. Owner enters address or drops a pin. Backend geocodes/validates coordinates and stores PostGIS point.
    
20. Owner chooses charger power, port connector(s), access rules, parking availability/fee and base price.
    
21. Backend validates sane power/price ranges and prevents duplicate charger creation at same business unless explicitly confirmed.
    
22. Owner defines recurring or one-off availability windows. Convert recurring schedules into queryable windows for the demo horizon.
    
23. Owner can pause a charger; pausing must not silently cancel existing confirmed bookings.
    

24. ## Separate three meanings of availability
    

|   |   |   |
|---|---|---|
|Concept|Example|Storage|
|Owner schedule|Tuesday 14:00-17:00 is offered|availability_windows|
|Live status|Port is AVAILABLE/OCCUPIED/OFFLINE/UNKNO WN|charger_status_events/current projection|
|Booking occupancy|14:30-15:15 already reserved|bookings|

  

3. ## Lightweight no-IoT trust system
    

4. Every status update records source: OWNER, DRIVER_CHECKIN, DRIVER_CHECKOUT, BOOKING_DERIVED, ADMIN or future CPO/IoT.
    
5. Assign source confidence. Recent checkout may be high confidence; old owner self-report decays.
    
6. Compute current status from newest valid signal plus active bookings.
    
7. Track mismatches: driver arrives but charger unavailable, owner cancellation, failed session.
    
8. Update reliability_score after completed/failed sessions. Use a Bayesian-smoothed or weighted score so a new charger is not unfairly 0% or 100%.
    
9. Expose last_updated_at and confidence to clients. Show 'Recently confirmed' rather than falsely claiming perfect real-time telemetry.  
    

10. # Phase 4 - Booking Engine: Your Most Important Backend Module
    

11. ## State machine
    

PENDING -> HELD -> PAYMENT_PENDING -> CONFIRMED

| | | |

| -> EXPIRED -> FAILED -> CANCELLED

| -> NO_SHOW

| -> CHECKED_IN

| |

| CHARGING

| |

+------------------------------------------> COMPLETED

  

2. ## Business rules to encode before writing endpoints
    

|   |   |
|---|---|
|Rule ID|Rule|
|BR-001|Vehicle connector must match charger port connector.|
|BR-002|Vehicle must be able to reach the charger with reserve margin.|
|BR-003|Confirmed/held bookings for the same port cannot overlap.|
|BR-004|A booking hold expires after a short TTL (e.g., 5 minutes).|
|BR-005|Payment must be verified server-side before confirmation.|
|BR-006|Owner cannot delete/alter a window that would invalidate a confirmed booking without an explicit cancellation workflow.|
|BR-007|Check-in allowed only inside configured early/late tolerance.|
|BR-008|State transitions are validated centrally; clients cannot set arbitrary status.|
|BR-009|Every transition writes booking_events.|
|BR-010|Create booking/payment/refund endpoints support idempotency keys.|

  

3. ## Exact reservation flow
    

4. Client requests a quote for port + slot. Backend rechecks compatibility, schedule, overlap and price.
    
5. Backend creates a Redis lock key scoped to port and slot using SET NX with TTL. If it fails, return 409 SLOT_UNAVAILABLE.
    
6. Inside a DB transaction, create booking status HELD with hold_expires_at and quote snapshot.
    
7. Create sandbox payment order if payment is enabled; transition to PAYMENT_PENDING.
    
8. Client completes payment. Backend verifies provider signature/status; never trust a client 'success=true'.
    
9. Inside a transaction, recheck booking hold and DB overlap constraint, then set CONFIRMED.
    
10. Delete/allow expiry of Redis lock. Confirmed booking is now protected by DB truth.
    
11. Celery task expires stale HELD/PAYMENT_PENDING records and releases inventory.
    
12. On cancellation, compute refund policy from timestamps, create refund asynchronously, and append event.
    

13. ## Concurrency test that will impress judges
    

Write an integration test that launches 20 concurrent booking requests for the same one-port slot. Exactly one may reach HELD/CONFIRMED; the rest must receive conflict/unavailable responses. Put the test result screenshot or terminal output in your final demo backup.  

7. # Phase 5 - EV-Aware Search, Reachability and Recommendation Engine
    

8. ## Candidate generation
    

9. Input driver origin, destination, current SOC, desired arrival reserve, vehicle and optional preferences.
    
10. Use route/polyline or origin radius to create a corridor. Query PostGIS for chargers near the route/corridor.
    
11. Hard-filter inactive/unverified chargers, closed businesses, incompatible connectors, unavailable ports and unreachable chargers.
    
12. Only after hard filters calculate ranking features.
    

13. ## Reachability calculation
    

usable_energy_kwh = battery_capacity_kwh * (current_soc - reserve_soc) estimated_reachable_km = usable_energy_kwh * efficiency_km_per_kwh

  

Reject a candidate if route distance to charger > estimated_reachable_km.

For demo safety, apply a configurable uncertainty margin rather than claiming exact range.

  

3. ## Charging-time estimate
    

effective_power_kw = min(vehicle_max_supported_kw, port_max_power_kw) required_energy_kwh = battery_capacity_kwh * (target_soc - current_soc) ideal_time_hr = required_energy_kwh / effective_power_kw estimated_charge_min = ideal_time_hr * 60 * taper_factor

  

Use a simple documented taper factor for prototype estimates; label as estimate.

  

4. ## Ranking formula
    

score =

w_detour * norm(detour_minutes)

+ w_wait * norm(predicted_wait_minutes)

+ w_charge * norm(estimated_charge_minutes)

+ w_cost * norm(estimated_cost)

+ w_reliability * norm(1 - reliability_score)

+ w_access * access_penalty

  

LOWER SCORE = BETTER

Return both score and explanation. The UI should never show a mysterious AI badge without reasons.

{

"charger_id": "chg_12", "rank": 1,

"estimated_detour_min": 6,

"predicted_wait_min": 0,

"estimated_charge_min": 27,

"estimated_cost_inr": 205,

"reliability": 0.94,

"confidence": 0.82,

"reason_codes": ["COMPATIBLE_FAST_CHARGER", "NO_QUEUE_EXPECTED", "HIGH_RELIABILITY"]

}

  

8. # Phase 6 - ML: Build Models That Can Survive Judge Questions
    

Do not build five weak models. Build two defensible predictive models and derive other recommendations from them.  

1. ## Model A - Demand forecasting
    

|   |   |
|---|---|
|Item|Plan|
|Target|Bookings/arrivals per charger or geospatial zone per 30/60-minute bucket|
|Features|hour, day_of_week, weekend/holiday, charger count, historical lag demand, rolling mean, business category, price, optional weather/event features|
|Baseline|same-hour previous-day/previous-week or rolling mean|
|Candidates|Gradient boosting / XGBoost/CatBoost if available; RandomForest/HistGradientBoosting as fallback|
|Metrics|MAE + RMSE; compare against baseline|
|Output|expected_demand, confidence/uncertainty proxy, model_version|

  

2. ## Model B - Occupancy / wait-time prediction
    

|   |   |
|---|---|
|Item|Plan|
|Target|wait_minutes or occupancy probability for charger/time bucket|
|Features|active bookings, recent session durations, ports, time/day, demand forecast, reliability, local supply|
|Baseline|queue from current bookings only|
|Model|regression for minutes or classification for LOW/MEDIUM/HIGH congestion|
|Metrics|MAE for wait; F1/AUC for congestion class|
|Output|predicted_wait_min, congestion_level, confidence|

  

3. ## Derived business intelligence
    

4. Generate candidate owner availability windows from business off-peak hours.
    
5. Score each window using forecast demand, nearby supply, expected utilization and owner constraints.
    
6. Recommend price within owner-configured floor/ceiling. Do not let model arbitrarily set extreme prices.
    
7. Return human-readable reason codes such as HIGH_DEMAND_LOW_SUPPLY, BUSINESS_OFF_PEAK and STRONG_HISTORICAL_CONVERSION.
    
8. Owner accepts/edits/rejects. Store response as future training/analytics signal.
    

9. ## ML data pipeline
    

PostgreSQL operational data

|

scheduled feature extraction (Celery)

|

feature dataset + train/validation split by TIME

|

baseline -> candidate models -> evaluation

|

choose model only if it beats baseline

|

joblib artifact + metadata/version

|

FastAPI inference adapter

|

ml_predictions table + recommendation service  

5. ## Avoid leakage
    

- Split train/validation chronologically, not random rows, because future demand must not leak into past training.
    
- Do not use booking outcome fields that are only known after prediction time.
    
- Record model version and generated_at with every prediction.
    
- If confidence is low or model unavailable, fall back to deterministic rules.
    

  
  

9. # Phase 7 - API Contract
    

  

|   |   |
|---|---|
|Area|Endpoints to finish|
|Auth|POST /auth/register, /auth/verify, /auth/login, /auth/refresh,<br><br>/auth/logout|
|Driver|GET/PATCH /users/me; CRUD /vehicles|
|Business|CRUD /businesses; /businesses/{id}/analytics; /recommendations|
|Chargers|CRUD /chargers; /chargers/nearby; /chargers/{id}; /ports;<br><br>/availability|
|Routes|POST /routes/recommendations; POST /routes/quote|
|Bookings|POST /bookings/hold; POST /bookings/{id}/confirm; cancel; GET detail/list|
|Sessions|POST check-in; start; complete; report-issue|
|Payments|create-order; verify; webhook; refund|
|ML|internal prediction endpoints or service calls; admin model health|
|System|/health/live; /health/ready; /version|

Standardize error bodies: code, message, request_id, optional field_errors. Generate OpenAPI docs and use them as the shared contract for both clients.

  

10. # WORKFLOW A - Build the Web Application (Next.js)
    

The web workflow should support two polished modes: Driver Web/PWA and Business Dashboard. If time is tight, make the business dashboard strongest on web and let Flutter be the primary driver experience.

1. ## Web project setup
    

2. Create Next.js with TypeScript, App Router and Tailwind CSS.
    
3. Create lib/api.ts with one typed API client. Do not scatter fetch calls across components.
    
4. Create auth provider/store and route guards based on server-provided role.
    
5. Create reusable design primitives: Button, Card, Stat, Badge, Drawer, MapPanel, Skeleton, EmptyState, ErrorState.
    
6. Create environment config for API base URL, Maps key and feature flags.
    
7. Add an error boundary and global toast system.
    

8. ## Route map
    

/

/login

/onboarding/driver

/onboarding/business

  

/driver

/map

/route  

/charger/[id]

/booking/[id]

/history

  

/business

/overview

/chargers

/availability

/bookings

/intelligence

/analytics

  

/admin

/verification

/system

  

3. ## Driver web build order
    

4. Build map shell first with current location, destination search and charger markers.
    
5. Call /chargers/nearby and render basic cards before adding route optimization.
    
6. Build vehicle selector and SOC control. Persist only non-sensitive preferences locally.
    
7. Call /routes/recommendations and show top 3 ranked options, not 20 markers.
    
8. Make the top card explain WHY: detour, wait, charge time, cost, reliability.
    
9. Build charger detail drawer with connector, power, hours, trust timestamp, amenities and slot picker.
    
10. Implement hold countdown visibly after reservation. If TTL expires, return user to slot selection.
    
11. Integrate sandbox payment and confirmation page.
    
12. Add check-in/out controls and session status timeline.
    

13. ## Business dashboard build order
    

14. Overview: utilization, bookings, charger revenue, reliability and today's availability.
    
15. Charger management: add/edit/pause charger and ports.
    
16. Availability calendar: owner-controlled windows and existing bookings.
    
17. Intelligence page: 'Recommended 2-5 PM' cards with forecast demand, confidence and reason.
    
18. One-click Accept, Edit, Reject. Accepted recommendation creates availability through normal backend service.
    
19. Analytics: hourly utilization heatmap, booking conversion, revenue, no-show rate, reliability trend.
    
20. Offers: optional business coupon/footfall incentive tied to charging booking.
    

21. ## Web polish that wins demos
    

- Use skeleton loading, optimistic UI only where safe, and explicit offline/API error states.
    
- Animate route/recommendation transitions lightly; do not sacrifice performance for effects.
    
- Use a visual confidence language: green/high confidence, neutral/stale, warning/low trust - with text labels, not color alone.
    
- Create a 'Why this charger?' expandable panel.
    
- Add a demo-mode switch that loads seeded Pune-style scenarios instantly without fake claims.
    

  
  

11. # WORKFLOW B - Build the Mobile Application (Flutter)
    

Flutter should be driver-first: location, route, recommendation, booking, payment and session. Business management can remain web-first unless the team has extra time.

1. ## Flutter setup
    

2. Create Flutter app with null safety and feature-first folder structure.
    
3. Choose one state management approach (Riverpod is a good fit); do not mix Provider/BLoC/Riverpod randomly.  
    
4. Use Dio or a single HTTP client wrapper with auth refresh interceptor and standardized error mapping.
    
5. Use go_router for navigation and guarded routes.
    
6. Add secure storage for refresh token; keep short-lived access token in memory where practical.
    
7. Add maps/location package and permission handling. Explain why location is needed before requesting permission.
    
8. Create flavor/env config for local, staging and production API URLs.
    

lib/

core/

api/ auth/ config/ errors/ theme/

features/ onboarding/ map/ route_planner/ chargers/ booking/ payment/ session/ history/

shared/ widgets/ models/

  

2. ## Mobile screen build order
    

3. Splash -> token refresh -> role/session decision.
    
4. Driver onboarding -> vehicle details -> connector/power capability.
    
5. Home map -> location -> destination search.
    
6. Route planner -> SOC slider -> reserve preference -> 'Find best charging stop'.
    
7. Recommendation bottom sheet -> top 3 options with explanation chips.
    
8. Charger detail -> live/trust status -> slots -> reserve.
    
9. Booking hold screen -> countdown -> payment.
    
10. Confirmed booking -> navigation handoff/map route.
    
11. Arrival -> check-in -> session status -> complete -> rating/issue report.
    
12. History -> booking/session details and receipts.
    

13. ## Flutter reliability requirements
    

- Handle app background/resume during payment and booking hold.
    
- Do not rely on local countdown as truth; refresh hold_expires_at from backend.
    
- Retry GETs safely; do not blindly retry booking/payment POSTs without idempotency keys.
    
- Cache last successful map/recommendation for UX, but label stale data.
    
- Test denied location permission, weak network, expired token, payment cancel and slot taken between view and hold.
    

  

12. # Sponsor Integration Plan - Use Every Sponsor Meaningfully
    

Sponsor usage should look native to the product. Build each behind an adapter/feature flag so the core demo survives if a sponsor service is unavailable.

  

|   |   |   |   |
|---|---|---|---|
|Sponsor|Product use|Implementation step|Demo proof|

  
  
  

|   |   |   |   |
|---|---|---|---|
|Swytchcode|Safe execution layer for AI-triggered external API actions|Create a sponsor integration adapter; allow an AI assistant to invoke approved read-only or low-risk actions such as retrieving configured data/integration results. Keep booking/payment mutations behind your own authorization.|Show an agent-triggered approved integration call and audit trail.|
|Render|Primary cloud deployment|Deploy FastAPI web service, PostgreSQL/PostGIS where supported/configured, Redis-compatible service if available in your setup, worker/cron/background processes as appropriate.|Open live staging URL; show health endpoint and deployed commit.|
|Tavily|Fresh web intelligence for optional EV policy/charging context|Backend-only search adapter. Use for 'EV ecosystem updates' or admin/business research cards; never put Tavily in the critical booking path.|Ask for a current EV ecosystem brief with cited sources.|
|n8n|Workflow automation|Webhook from booking/session events -> notification/CRM/logging/dem o workflow. Also automate owner daily summary.|Show visual workflow triggered by completed booking.|
|CodeMate AI|Development quality assistant|Use during implementation for code review/refactoring/test suggestions; document one concrete before/after improvement in README.|Show sponsor attribution in engineering/tooling page and PR evidence.|
|startuped|GTM/business validation|Use framework/resources to sharpen target customer, pilot pitch, acquisition and monetization assumptions; keep this in business dashboard/about/demo deck rather than runtime dependency.|Show a one-page pilot/GTM artifact or business onboarding strategy.|
|Lyzr|Business/operations AI agent|Create a VoltEZ Business Copilot agent that explains utilization, summarizes recommendations and can call safe read-only VoltEZ tools via REST.|Ask 'Why should I open my charger 2-5 PM?' and return structured answer.|
|Google for Developers|Core developer ecosystem|Use Google Maps Platform/Places where available; optionally Firebase/Google developer tooling if genuinely used. Keep API abstraction so Mapbox can substitute.|Route/map search visible in driver flow.|
|MLH|Hackathon engineering practice/community|Use MLH-style project documentation, demo readiness, open-source hygiene and judging preparation; credit in About/README where|Show polished README, architecture and demo checklist.|

  
  
  

|   |   |   |   |
|---|---|---|---|
|||appropriate.||
|Google Gemini|Natural-language explanation layer|Use Gemini to convert structured recommendation facts into concise driver/business explanations; never let LLM invent price, wait time or availability.|Toggle 'Explain recommendation' and show response grounded only in structured facts.|

  
  

13. # External Integrations and Adapter Pattern
    

class MapsProvider:

async def geocode(...) async def route(...) async def matrix(...)

  

class PaymentProvider:

async def create_order(...) async def verify(...)

async def refund(...)

  

class SearchProvider: async def search(...)

  

class AgentProvider:

async def explain_recommendation(...)

  

# services depend on interfaces, not vendor SDKs directly

97. Create integrations/maps/google_maps.py and integrations/maps/mapbox.py behind MapsProvider.
    
98. Create integrations/payments/razorpay.py behind PaymentProvider.
    
99. Create integrations/search/tavily.py for optional current-context search.
    
100. Create integrations/agents/gemini.py and/or lyzr.py for explanations/copilot.
    
101. Wrap sponsor calls with timeouts, retries where safe, circuit-breaker/fallback behavior and logging.
    
102. Never expose vendor API keys to browser/mobile unless the provider explicitly requires a restricted public key. Keep privileged keys server-side.
    

  

103. # Phase 8 - Testing Plan
    

  

|   |   |
|---|---|
|Layer|Tests you must have|
|Unit|booking state transitions; pricing bounds; compatibility; reachability; reliability calculation; ranking score|
|Repository|PostGIS nearby query; overlap query; transaction behavior|
|Integration|register/login; charger creation; hold/confirm/cancel; payment verify; session complete|
|Concurrency|20 simultaneous holds for one slot -> one winner|
|ML|feature generation; no leakage; baseline comparison; artifact load; fallback|
|Web|critical route planner and booking flow; role guards; API error|

  
  
  

|   |   |
|---|---|
||state|
|Flutter|auth refresh; permission denial; hold expiry; payment cancel; resume from background|
|E2E|seed -> owner availability -> driver recommendation -> booking<br><br>-> session -> dashboard update|

  

## Failure injection checklist

- Maps timeout: show fallback message/cached nearby chargers.
    
- ML model unavailable: deterministic wait/ranking fallback.
    
- Gemini/Lyzr unavailable: hide explanation enhancement; booking still works.
    
- Redis unavailable: fail reservation safely rather than risk double booking; optionally DB-only guarded path.
    
- Payment webhook delayed: show pending and reconcile later.
    
- Stale charger status: lower confidence and surface timestamp.
    

  
  

15. # Security and Privacy Baseline
    

- Hash passwords with a modern password hash; never encrypt/store plaintext passwords.
    
- JWT validation includes expiry, issuer/audience if configured, token type and role checks.
    
- Rate-limit auth/OTP and expensive recommendation endpoints.
    
- Validate all coordinates, times, IDs, prices and ownership on backend.
    
- Do not log access tokens, OTPs, payment secrets or raw sensitive credentials.
    
- Use least-privilege database and API credentials.
    
- Store only location history needed for the feature; give users clear control over location permission.
    
- Use server-side payment verification and signed webhook verification.
    
- Admin actions and booking state changes should be auditable.
    

  
  

16. # Phase 9 - Deployment on Render and Release Pipeline
    

17. Create staging and production environments. Hackathon demo should use staging until frozen.
    
18. Provision PostgreSQL with PostGIS support/configuration and Redis-compatible cache/broker as your chosen deployment supports.
    
19. Deploy FastAPI from GitHub. Start command should bind to 0.0.0.0 and platform-provided port.
    
20. Run Alembic migrations as a controlled release step, not automatically from every worker.
    
21. Deploy Celery worker/background worker only after synchronous flow is stable.
    
22. Deploy Next.js separately (Render or another allowed frontend host). Configure API CORS to exact origins.
    
23. Build Flutter Android APK for judges and keep a tested backup device/build.
    
24. Add /health/live, /health/ready and /version with git SHA/build identifier.
    
25. Seed staging with deterministic demo data. Never seed production automatically.
    
26. Freeze deploy at least 60-90 minutes before judging; after freeze only critical fixes.
    

  
  

27. # 48-Hour Hackathon Execution Timeline
    

  

|   |   |   |   |   |   |
|---|---|---|---|---|---|
|Window|Backend|Web|Flutter|ML/Integration|Milestone|
|H0-4|Repo, Docker, DB, migrations, seed|Scaffold/theme/ auth shell|Scaffold/theme/ auth shell|Dataset plan + sponsor keys|Everyone runs stack|
|H4-10|Auth, businesses, chargers, ports,|Business charger|Driver|Generate/clean|Chargers visible|

  
  
  

|   |   |   |   |   |   |
|---|---|---|---|---|---|
||PostGIS|CRUD|onboarding/map|seed history||
|H10-16|Availability + booking state machine + Redis lock|Availability UI + booking admin|Recommendation cards + charger detail|Demand baseline/model|Booking hold works|
|H16-24|Recommendation service + route/compatibility|Driver web route + owner intelligence|Route planner + booking|Wait model + inference adapter|End-to-end without payment|
|H24-30|Payment sandbox<br><br>+ sessions + analytics|Dashboard analytics|Payment/check-in/session|Gemini/Lyzr/Tavily adapters|Golden path complete|
|H30-36|Celery tasks + hardening|Polish/error states|Polish/offline states|n8n + sponsor proof|Feature freeze|
|H36-42|Tests, concurrency, logs|E2E test|APK/device test|Model metrics + fallbacks|Reliability pass|
|H42-48|Deploy/fix only|Demo polish|Demo polish|Pitch metrics|Demo rehearsal x3|

  

18. # Team Ownership Model
    

  

|   |   |   |
|---|---|---|
|Owner|Primary responsibility|Must coordinate with|
|Backend/business logic|Booking, availability, matching, pricing, recommendation orchestration, API contracts|ML + both clients|
|Backend/infra|DB/PostGIS, Redis, Celery, auth base, Render, CI/CD, observability|Business logic|
|Web|Business dashboard + optional driver PWA|API contract|
|Flutter|Driver mobile golden path|API contract + maps/payment|
|ML|Demand/wait models, features, metrics, artifacts, fallback contract|Backend intelligence service|
|Product/demo|Seed scenario, sponsor proof, README, judging story, QA checklist|Everyone|

  

19. # Judge Demo Script - 4 to 6 Minutes
    

20. Problem in 20 seconds: chargers exist but discovery, trust and utilization are fragmented.
    
21. Owner side: open dashboard. Show low-utilization hours and AI recommendation 'Open 2-5 PM'. Expand 'Why?' with forecast + nearby supply + confidence. Accept.
    
22. Driver side: select vehicle, set SOC, destination. Show system rejecting incompatible/unreachable options silently and returning top 3.
    
23. Open 'Why this charger?': detour + predicted wait + charge time + cost + reliability.
    
24. Reserve. Point out the temporary hold countdown and explain Redis + DB protection against double booking.
    
25. Complete sandbox payment/check-in/session quickly or use a prepared near-complete session.
    
26. Return to business dashboard: utilization/revenue/session metrics update.
    
27. Show one sponsor-powered enhancement: Gemini/Lyzr explanation, n8n event workflow or Tavily ecosystem brief.
    
28. Close with architecture and measurable proof: deployed system, concurrency test, model beats baseline, graceful fallback.  
    

## Questions industry experts are likely to ask

|   |   |
|---|---|
|Question|Strong answer direction|
|How is availability real-time without IoT?|We expose confidence and source, combine owner schedule, booking truth and check-in/out events, decay stale signals, and leave an adapter for future CPO/IoT feeds.|
|Where does ML data come from?|Prototype uses clearly labeled seeded/synthetic history plus real app events; model is evaluated against a baseline and is not used when confidence/model health is poor.|
|Why AI?|Forecasting demand/wait is predictive; ranking is optimization; LLMs explain structured outputs. We deliberately do not call deterministic booking logic AI.|
|How do you prevent double booking?|Redis NX hold + TTL for fast coordination, DB transaction/overlap protection as source of truth, idempotency keys and concurrency tests.|
|What is unique?|Off-peak revenue intelligence aligns driver charging demand with a business's slow hours, converting idle charger capacity into utilization and footfall.|
|Can it scale?|Spatial index for candidate search, caching for repeated nearby queries, async jobs for non-request work, stateless API, vendor adapters and clear module boundaries.|

  
  

20. # Build It So It Becomes an Internship Portfolio Piece
    

- README starts with problem, live demo, architecture diagram, screenshots, tech decisions and measurable results.
    
- Include an Architecture Decision Record explaining modular monolith vs microservices.
    
- Publish API OpenAPI docs and a Postman/Bruno collection.
    
- Show one benchmark: PostGIS nearby query latency, concurrent booking test, or recommendation latency.
    
- Show ML evaluation table against baseline and limitations.
    
- Include automated tests in CI and a badge if appropriate.
    
- Include a 90-second product demo video and a 5-minute technical walkthrough.
    
- Write a 'What we would build next' section: OCPP/CPO integration, stronger telemetry, settlement, multi-city pilots, production monitoring.
    

  

21. # Final Shipping Checklist
    

- Fresh clone can run locally from README.
    
- Database migrations apply cleanly.
    
- Seed script creates deterministic demo.
    
- Driver can register/login and add vehicle.
    
- Owner can add business/charger/ports.
    
- PostGIS nearby search works.
    
- Availability windows are distinct from live status.
    
- Compatibility + reachability hard filters work.
    
- Top recommendations include explanations.
    
- Booking hold expires correctly.  
    
- Concurrent booking test has one winner.
    
- Payment is verified server-side in sandbox.
    
- Check-in/session completion updates analytics.
    
- Demand model has baseline and metric.
    
- Wait model/fallback returns valid values.
    
- Owner intelligence is explainable and owner-controlled.
    
- All sponsor integrations have visible proof or documented development/GTM usage.
    
- External API failure does not break booking core.
    
- Web critical flow tested.
    
- Flutter APK tested on physical device.
    
- Staging deployment health endpoints green.
    
- Demo rehearsed with backup screenshots/video.
    

  
  

22. # Source Alignment and Research Notes
    

Source deck alignment: VoltEZ's supplied ideation deck frames the project as an EV mobility intelligence platform, identifies underutilized private/commercial chargers, proposes discovery/booking, dynamic pricing, demand forecasting, route optimization and lightweight check-in/check-out, and emphasizes off-peak revenue intelligence for businesses. This playbook preserves that product framing while resolving the deck's mixed backend-stack descriptions into one FastAPI modular monolith.

Sponsor research used to make the integration plan concrete: Swytchcode documentation describes an execution layer for AI agents to discover/execute real APIs; Render documentation supports Python/FastAPI web-service deployment from Git repositories or Docker; Tavily describes a search API designed for AI applications; Lyzr documentation describes agents exposed through APIs with tools/knowledge/memory; Google/Gemini is used only as an explanation layer over structured facts. Where sponsor access, credits or APIs differ during the event, keep the adapter and feature flag and do not make the core booking flow depend on them.

## Recommended final architecture

CLIENTS

Next.js Business Web Flutter Driver App

\ /

\ REST + JWT /

FastAPI

+-----------+ +

| | |

Auth Booking Intelligence

| | |

| Redis Holds Demand/Wait ML

| | |

+------ PostgreSQL/PostGIS +

| Celery/background jobs

|

Maps | Payment | n8n | Tavily | Gemini/Lyzr | Swytchcode

|

observability + audit events

  

Rule: external intelligence enhances the system; PostgreSQL + deterministic business rules remain truth.

###  Final principle  

**