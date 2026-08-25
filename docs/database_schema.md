# VoltEZ Application Database Blueprint v1.1

Status: design only
Branch: `ML-Arnav`
Database target: PostgreSQL with PostGIS
Primary objective: support the complete VoltEZ application while producing trustworthy data for demand forecasting and charger availability prediction.

The backend diagram `VoltEZ_Database_Schema_v1_1.png` is the current source design. See
[`schema_reconciliation_v1_1.md`](schema_reconciliation_v1_1.md) for the exact ML-generator
mapping, the duplicate status-table clarification, and two additive relationship fixes.

## 1. Design decisions

1. PostgreSQL is the permanent source of truth for users, chargers, bookings, payments, and sessions.
2. Redis may later hold locks, short-lived booking holds, caches, and fresh predictions, but Redis never becomes booking truth.
3. Physical charging capacity is represented by `charger_ports`. A booking reserves a port, not an entire multi-port site.
4. Business operating hours, charger listing hours, technical status, booking occupancy, and predicted availability are separate concepts.
5. Demand is measured from driver requests and searches, not only completed bookings. Bookings show fulfilled demand and would hide unmet demand.
6. All important state changes are append-only events. Current state may be stored for fast reads, but the event history must allow reconstruction.
7. Operational application data, derived analytics, and synthetic ML data remain logically separated.
8. Timestamps are stored as `timestamptz` in UTC. The application converts them to the relevant local timezone, initially `Asia/Kolkata`.
9. Every model prediction records when it was generated, the future time it describes, its model version, its feature cutoff, and whether a fallback was used.
10. Personally identifying fields are excluded from ML training views.

## 2. Recommended PostgreSQL schemas

| Schema | Responsibility |
| --- | --- |
| `app` | Transactional application entities and append-only operational events |
| `analytics` | Derived time buckets, feature snapshots, outcomes, and prediction records |
| `ml_lab` | Synthetic or experimental datasets that must never be mistaken for production truth |

For the hackathon, these may run in one PostgreSQL database. The schema boundary should still be retained.

## 3. Shared conventions

### Primary keys

- Use UUID primary keys for user-facing and distributed entities.
- Small lookup tables may use short integer keys.
- Every foreign key column uses the same type as its referenced primary key.

### Standard timestamps

Most mutable records contain:

- `created_at`
- `updated_at`

Append-only event tables contain:

- `event_time`: when the real-world event happened
- `ingested_at`: when VoltEZ received it
- `created_at`: when the database row was created

The distinction matters because delayed events must not be treated as if the model knew them earlier.

### Soft deletion

Use `deleted_at` for users, vehicles, businesses, chargers, and ports when historical bookings must remain valid. Do not physically delete a charger referenced by a past session.

### Money and energy

- Store money using `numeric`, never floating-point values.
- Store currency explicitly, initially `INR`.
- Store energy as `numeric` kWh.
- Store SOC as a percentage constrained to `0 <= soc <= 100`.

### Time intervals

Treat bookable intervals as half-open intervals: `[start_at, end_at)`. A booking ending at 15:00 does not overlap one beginning at 15:00.

## 4. Application entities

### 4.1 `app.users`

Purpose: authentication identity and role-based access control.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `name` | Display name; excluded from ML views |
| `email` | Nullable, unique when present |
| `phone` | Nullable, unique when present |
| `password_hash` | Never exposed outside authentication services |
| `role` | `driver`, `host`, `admin`, or `support` |
| `verification_status` | `unverified`, `pending`, `verified`, or `rejected` |
| `timezone` | Defaults to `Asia/Kolkata` |
| `created_at`, `updated_at`, `deleted_at` | Audit fields |

Rules:

- At least one of `email` or `phone` must be present.
- ML datasets use a non-reversible training identifier instead of `id`, email, phone, or name.

### 4.2 `app.vehicles`

Purpose: compatibility, charging-time estimation, and route intelligence.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `user_id` | Owner; references `app.users` |
| `make`, `model`, `model_year` | Nullable descriptive data |
| `vehicle_class` | `two_wheeler`, `three_wheeler`, `car`, `van`, or `other` |
| `battery_kwh` | Positive battery capacity |
| `max_ac_kw`, `max_dc_kw` | Non-negative charging limits |
| `estimated_range_km` | Optional display estimate |
| `efficiency_wh_per_km` | Optional route-energy prior |
| `created_at`, `updated_at`, `deleted_at` | Audit fields |

Connector compatibility is many-to-many and should not be stored as an unvalidated string array.

### 4.2.1 `app.vehicle_energy_profiles`

Purpose: version the physical and battery priors used for route-energy estimates without rewriting
historical decisions when a specification is corrected.

Fields: `id`, `vehicle_id`, `effective_from`, `effective_to`, `source`, `confidence`,
`curb_mass_kg`, `default_payload_kg`, `drag_area_m2`, `rolling_resistance_coefficient`,
`drivetrain_efficiency`, `regenerative_braking_efficiency`, `usable_capacity_fraction`,
`battery_health_fraction`, `created_at`.

Rules:

- validity intervals for one vehicle must not overlap;
- source and confidence are required because catalogue, owner, and class-default values have
  different certainty;
- a profile is a planning-time estimate, not immutable physical truth;
- prediction records reference the profile version they used.

### 4.3 `app.connector_types`

Purpose: controlled connector vocabulary.

Fields: `id`, `code`, `display_name`, `charging_type`, `created_at`.

Example codes may include CCS2, Type 2, CHAdeMO, Bharat AC-001, or Bharat DC-001. The final vocabulary must be verified before implementation.

### 4.4 `app.vehicle_connectors`

Purpose: connectors accepted by a vehicle.

Fields: `vehicle_id`, `connector_type_id`, `is_preferred`.

Constraint: unique pair `(vehicle_id, connector_type_id)`.

### 4.5 `app.zones`

Purpose: stable geographic unit for demand forecasting, aggregation, privacy, and city expansion.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `city` | Initially Pune |
| `name` | Human-readable zone label |
| `h3_index` | Recommended spatial cell identifier after resolution is selected |
| `boundary` | PostGIS polygon or multipolygon |
| `centroid` | PostGIS point |
| `timezone` | Defaults to `Asia/Kolkata` |
| `zone_type` | Controlled land-use category such as residential, office, retail, transit, or mixed |
| `active` | Whether new records may reference the zone |

Do not choose the final H3 resolution until Pune map density and privacy requirements are tested. Store the chosen resolution in configuration and dataset manifests.

### 4.6 `app.businesses`

Purpose: commercial or residential charger host.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `owner_id` | References a host user |
| `zone_id` | References `app.zones` |
| `name`, `category` | Category uses a controlled vocabulary |
| `location` | PostGIS point |
| `address_text` | Display address; excluded from broad ML exports |
| `timezone` | Normally inherited from zone |
| `verification_status` | Host verification state |
| `access_notes` | Human-readable instructions |
| `created_at`, `updated_at`, `deleted_at` | Audit fields |

### 4.7 `app.business_hours`

Purpose: recurring access hours without forcing owners to create endless dated intervals.

Fields: `id`, `business_id`, `day_of_week`, `open_local_time`, `close_local_time`, `is_closed`, `effective_from`, `effective_to`.

One-off closures and holidays belong in a separate exception table.

### 4.8 `app.business_hour_exceptions`

Purpose: holidays, closures, and special opening periods.

Fields: `id`, `business_id`, `start_at`, `end_at`, `exception_type`, `reason`, `created_at`.

### 4.9 `app.amenities` and `app.business_amenities`

Purpose: amenity-aware recommendations such as cafes, restrooms, Wi-Fi, shopping, or parking.

`amenities` fields: `id`, `code`, `display_name`.
`business_amenities` fields: `business_id`, `amenity_id`, `verified_at`, `source`.

### 4.9.1 `app.business_offers`

Purpose: support VoltEZ's retail thesis by letting hosts attach a real, time-bounded offer to a charging visit.

Fields: `id`, `business_id`, `title`, `description`, `start_at`, `end_at`, `redemption_type`, `redemption_value`, `terms`, `status`, `created_at`, `updated_at`.

Offer redemption should later be recorded as an observable event. The presence of an offer may become a recommendation feature, but simulated offer uplift must not be presented as measured business impact.

### 4.10 `app.chargers`

Purpose: physical charging unit located at a business.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `business_id`, `zone_id` | Host and forecast zone |
| `name` | Display label |
| `location` | PostGIS point; may inherit business location |
| `access_type` | Public, customer-only, residents-only, or controlled |
| `status` | Draft, active, paused, suspended, or retired |
| `reliability_score` | Nullable application projection; never direct Model 2 training truth |
| `created_at`, `updated_at`, `deleted_at` | Audit fields |

Do not store predicted reliability as permanent charger truth. Reliability is a versioned derived value.

### 4.11 `app.charger_ports`

Purpose: independently bookable connector and capacity unit.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `charger_id` | Parent charger |
| `connector_type_id` | Physical connector |
| `port_number` | Unique within a charger |
| `max_power_kw` | Positive power limit |
| `current_status` | Available, occupied, faulted, offline, maintenance, or unknown |
| `last_seen_at` | Freshness of denormalized status |
| `created_at`, `updated_at`, `deleted_at` | Audit fields |

`current_status` is a fast-read projection. `charger_status_events` remains the historical evidence.

### 4.11.1 `app.parking_spaces`

Purpose: reserve the physical parking resource promised by VoltEZ's smart-reservation feature.

Fields: `id`, `charger_id`, `label`, `accessibility_type`, `status`, `created_at`, `updated_at`, `deleted_at`.

A port may be permanently mapped to one parking space or a booking may choose an eligible space dynamically. Parking availability is deterministic application state and must not be inferred from charger availability alone.

### 4.12 `app.availability_windows`

Purpose: owner-approved dated bookability for a port.

Fields: `id`, `port_id`, `start_at`, `end_at`, `source`, `status`, `price_override_per_kwh`, `created_by`, `created_at`, `updated_at`.

Rules:

- `end_at > start_at`.
- The interval must fall within business access hours unless an approved exception applies.
- Source examples: owner, recurring schedule expansion, administrator, or approved ML recommendation.
- An ML recommendation never activates a window without owner opt-in.

### 4.13 `app.charger_status_events`

Purpose: append-only evidence for the no-IoT status and future availability model.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `charger_id`, `port_id` | Parent charger and physical port; both must agree |
| `status` | Available, occupied, faulted, offline, maintenance, or unknown |
| `source` | Owner, driver check-in, driver check-out, booking, support, system, or future IoT |
| `reporter_user_id` | Nullable actor |
| `confidence` | Source confidence from zero to one |
| `observed_at` | When the status was observed |
| `ingested_at` | When VoltEZ received the observation |
| `expires_at` | Time after which the observation should not be treated as current |
| `evidence_type` | QR, GPS, owner declaration, booking-derived, support verification, or IoT |
| `evidence_metadata` | Restricted JSON metadata, excluding unnecessary PII |

Do not store the availability model's final probability here as an input feature. A source-quality prior may be derived separately and versioned.

### 4.14 `app.charging_requests`

Purpose: measure total driver demand, including demand that does not become a booking.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `user_id`, `vehicle_id` | Nullable for permitted anonymous exploration |
| `origin_zone_id`, `zone_id` | Coarse origin and requested charging zone |
| `origin_point`, `destination_point` | Restricted operational coordinates with retention policy |
| `requested_at` | Prediction origin time |
| `desired_start_at` | Nullable requested charging time |
| `current_soc`, `reserve_soc`, `target_soc` | Nullable but validated when supplied |
| `required_connector_type_id` | Nullable until vehicle is known |
| `request_type` | Nearby search, route planning, or scheduled search |
| `result_status` | Served, no_candidate, abandoned, or error |
| `trip_id` | Nullable v1.1 extension linking route-planning demand to a journey |
| `created_at` | Audit field |

This table is the primary source for Model 1's demand label. Exact coordinates must not enter training exports directly.

### 4.15 `app.trips` and `app.trip_charger_options`

Purpose: represent a driver's journey and the charger alternatives considered along it.

`trips` fields: `id`, `user_id`, `vehicle_id`, `start_location`, `destination_location`,
`started_at`, `ended_at`, `distance_km`, `status`.

`trip_charger_options` fields: `trip_id`, `charger_id`, `rank`, `estimated_detour_km`,
`estimated_arrival_at`, `estimated_charge_time_min`, `estimated_total_cost`, `route_snapshot_id`.

Route-planning requests use the additive `charging_requests.trip_id` foreign key so the trip is
not matched heuristically by user and timestamp.

Ordinary trips may exist without a charging request. This supports destination reachability and
energy planning before the driver begins a charger search.

### 4.15.1 `app.route_snapshots`

Purpose: preserve the immutable route/context response used for one destination or candidate-
charger energy decision.

Fields: `id`, `trip_id`, nullable `request_id`, `vehicle_id`, nullable `candidate_charger_id`,
`leg_type`, `provider`, `provider_route_id`, `route_hash`, `requested_at`, `generated_at`,
`expires_at`, restricted origin/destination points, distance, normal/traffic duration, elevation
and grade summaries, urban/highway fractions, estimated stops, timestamped weather summaries,
source-quality fields, and `created_at`.

Rules:

- a trip references one direct destination snapshot;
- every candidate option references its origin-to-charger snapshot;
- snapshots are immutable; refreshed provider data creates a new row;
- exact coordinates follow a restricted retention policy and are excluded from training exports;
- missing elevation or weather remains null with an explicit quality state, never numeric zero;
- realized energy, post-trip duration, and arrival SOC do not belong in this table.

### 4.16 `app.recommendation_impressions`

Purpose: record all candidates shown, not only the selected charger.

Fields: `id`, `user_id`, `request_id`, `charger_id`, `port_id`, `rank`, `score_components`, `model_versions`, `shown_at`, `selected`, `selected_at`, `booking_id`.

This prevents future ranking models from learning only from winners and supports explainable replay.

### 4.16 `app.bookings`

Purpose: reservation lifecycle and permanent booking truth.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `user_id`, `vehicle_id`, `port_id` | Required references |
| `parking_space_id` | Nullable only when the site does not reserve a separate parking resource |
| `request_id` | Nullable link to originating demand request |
| `start_at`, `end_at` | Reserved half-open interval |
| `status` | Pending, held, payment_pending, confirmed, checked_in, charging, completed, expired, cancelled, no_show, payment_failed |
| `hold_expires_at` | Required only while held |
| `expected_arrival_at` | ETA known at booking time |
| `quote_snapshot` | Immutable price and fee breakdown shown to user |
| `created_at`, `confirmed_at`, `cancelled_at`, `updated_at` | Lifecycle timestamps |
| `cancellation_reason` | Nullable controlled code plus optional note |

Critical integrity rule: overlapping active booking intervals for one port must be prevented in PostgreSQL, not only by Redis.

### 4.17 `app.booking_events`

Purpose: append-only booking state history.

Fields: `id`, `booking_id`, `old_status`, `new_status`, `actor_type`, `actor_id`, `metadata`, `created_at`, `ingested_at`.

Every booking status transition creates exactly one event. Invalid transitions are rejected by the service layer and tested.

### 4.18 `app.charging_sessions`

Purpose: actual arrival, access, charging, and completion outcome.

| Field | Notes |
| --- | --- |
| `id` | UUID primary key |
| `booking_id` | Nullable only for explicitly supported walk-ins |
| `port_id`, `vehicle_id`, `user_id` | Explicit references |
| `arrived_at`, `check_in_at` | Physical arrival and application check-in |
| `queue_joined_at`, `service_ready_at` | Evidence for queue time without mixing in cable/setup delay |
| `start_at`, `end_at` | Actual charging timeline |
| `start_soc`, `end_soc` | Nullable validated percentages |
| `energy_kwh` | Non-negative delivered energy |
| `meter_start_kwh`, `meter_end_kwh` | Auditable cumulative meter readings |
| `final_amount`, `currency` | Final session price |
| `status` | Arrived, checked_in, charging, completed, abandoned, or failed |
| `failure_reason` | Charger fault, access denied, metadata mismatch, payment, driver, or other controlled reason |
| `created_at`, `updated_at` | Audit fields |

These outcomes are essential for Models 2, 3, and 4. Driver no-shows must not be counted as
charger failures, and congestion must not be presented as broken hardware.

### 4.19 `app.payments`

Purpose: server-verified payment truth.

Fields: `id`, `booking_id`, `provider`, `provider_order_id`, `provider_payment_id`, `amount`, `currency`, `status`, `signature_verified`, `verified_at`, `created_at`, `updated_at`.

Provider identifiers are unique. Booking confirmation cannot rely on a frontend `payment_success` flag.

### 4.19.1 `app.refunds`

Purpose: auditable refund lifecycle without overwriting the original payment.

Fields: `id`, `payment_id`, `provider_refund_id`, `amount`, `currency`, `reason`, `status`, `requested_at`, `verified_at`, `created_at`, `updated_at`.

### 4.19.2 `app.host_settlements`

Purpose: aggregate completed-session earnings owed to charger hosts.

Fields: `id`, `business_id`, `period_start`, `period_end`, `gross_amount`, `platform_fee`, `refund_adjustment`, `net_amount`, `currency`, `status`, `provider_reference`, `paid_at`, `created_at`, `updated_at`.

Investment pooling and regulated return distribution are deliberately not included in the initial transaction schema. That feature requires a separate legal and financial design before implementation.

### 4.20 `app.reviews`

Purpose: user feedback and reliability evidence.

Fields: `id`, `session_id`, `user_id`, `charger_id`, `rating`, `issue_flags`, `comment`, `created_at`, `moderation_status`.

Free-text comments are excluded from the first two numerical models. Issue flags may later support reliability analysis after moderation.

### 4.21 `app.notifications`

Purpose: asynchronous communication state.

Fields: `id`, `user_id`, `booking_id`, `type`, `channel`, `payload`, `status`, `scheduled_at`, `sent_at`, `failed_at`, `provider_reference`, `created_at`.

### 4.21.1 `app.audit_events`

Purpose: security and administrative audit trail separate from domain-specific booking events.

Fields: `id`, `actor_type`, `actor_id`, `action`, `entity_type`, `entity_id`, `request_id`, `event_time`, `ip_hash`, `metadata`.

Sensitive values, credentials, raw payment data, and unnecessary location data must never be written to audit metadata.

### 4.22 `app.tariffs`

Purpose: time-bounded charger or port pricing used for quotes and final billing.

Fields: `id`, `charger_id`, `port_id`, `price_per_kwh`, `price_per_minute`, `booking_fee`,
`starts_at`, `ends_at`.

The applicable tariff is copied into `bookings.quote_snapshot`; later tariff edits never rewrite
the price the driver accepted.

### 4.23 `analytics.context_events`

Purpose: optional zone/time context such as festivals, stadium events, severe weather, road disruption, or holidays.

Fields: `id`, `zone_id`, `event_type`, `starts_at`, `ends_at`, `expected_impact`, `source`,
`published_at`, `ingested_at`.

Model 1 must retain a fallback path that works when contextual sources are unavailable.

## 5. Analytics and ML entities

### 5.1 `analytics.demand_buckets`

Purpose: derived complete time grid used by Model 1.

Fields:

- `zone_id`
- `bucket_start`
- `bucket_minutes`
- `search_count`
- `request_count`
- `served_request_count`
- `no_candidate_count`
- `unserved_count`
- `booking_count`
- `session_count`
- `occupancy_rate`
- `compatible_ports_listed`
- `compatible_ports_available`
- `generated_at`
- `source_snapshot_id`

Primary key: `(zone_id, bucket_start, bucket_minutes)`.

Zero-demand buckets must exist. Missing rows cannot be treated as zero without proving the ingestion job ran successfully.

### 5.2 `analytics.availability_observations`

Purpose: point-in-time training rows and observed outcomes for Model 2.

Fields:

- `observation_id`
- `request_id`
- `port_id`
- `prediction_origin`
- `target_arrival_at`
- `observed_at`
- `feature_cutoff`
- `eligible_at_origin`
- `label`: available, unavailable, or unknown
- `label_source`
- `confidence`
- `booking_state`, `port_status`: target-time label context, forbidden as origin-time features
- `label_observed_at`
- `censoring_reason`
- `source_snapshot_id`

Unknown outcomes remain unknown and are excluded or handled explicitly. They are never silently converted to unavailable.

### 5.3 `analytics.waiting_time_observations`

Purpose: observed queue outcomes for Model 3.

Fields: `observation_id`, `request_id`, `booking_id`, `session_id`, `port_id`,
`prediction_origin`, `feature_cutoff`, `target_arrival_at`, `actual_arrival_at`,
`label_wait_minutes`, `label_known`, `label_source`, `label_observed_at`, `outcome`,
`source_snapshot_id`.

The label measures time until the port is service-ready. Charger faults remain unknown for the
queue target rather than being converted into long waits.

### 5.4 `analytics.reliability_observations`

Purpose: verified service outcomes for Model 4.

Fields: `observation_id`, `request_id`, `booking_id`, `session_id`, `port_id`,
`prediction_origin`, `feature_cutoff`, `target_arrival_at`, `label`, `label_source`,
`label_observed_at`, `failure_reason`, `source_snapshot_id`.

Labels are reliable, unreliable, or unknown. Only completed charging and verified intrinsic
charger failures become supervised truth. Queueing, driver behavior, and cancellations are not
hardware-failure labels.

### 5.5 `ml_lab.feature_snapshots`

Purpose: immutable, reproducible model input rows.

Fields: `id`, `model_name`, `entity_type`, `entity_id`, `prediction_origin`, `target_time`, `feature_cutoff`, `feature_view_version`, `features`, `source_snapshot_id`, `created_at`.

JSONB may be used during the first prototype, but stable high-value features should eventually become typed columns or a versioned Parquet dataset.

### 5.6 `ml_lab.ml_predictions`

Purpose: audit every model or fallback result used by the application.

Fields:

- `id`
- `request_id`
- `entity_type`, `entity_id`
- `model_name`, `model_version`
- `prediction_type`
- `prediction_origin`, `prediction_for`, `generated_at`
- `feature_cutoff`, `feature_view_version`
- `value`, `lower_bound`, `upper_bound`, `confidence`
- `is_fallback`, `fallback_reason`
- `top_factors`
- `latency_ms`

### 5.7 `ml_lab.model_registry`

Purpose: track champion, challenger, artifact identity, and rollback.

Fields: `model_name`, `version`, `stage`, `artifact_uri`, `artifact_sha256`, `feature_view_version`, `training_snapshot_id`, `metrics`, `approved_by`, `approved_at`, `created_at`.

Training a candidate never automatically changes the champion.

### 5.8 `ml_lab.simulation_runs`

Purpose: synthetic dataset lineage.

Fields: `id`, `generator_version`, `seed`, `city`, `start_at`, `end_at`, `bucket_minutes`, `scenario_config`, `row_counts`, `schema_hash`, `output_manifest_uri`, `created_at`.

Synthetic operational tables should live under `ml_lab` or in versioned Parquet files and reference `simulation_run_id`. They must not be inserted into `app` production tables without a clearly isolated development database.

## 6. Required constraints

1. Booking `end_at` must be later than `start_at`.
2. Active bookings for the same port must not overlap.
3. Availability windows must not have non-positive duration.
4. `battery_kwh`, `max_power_kw`, `energy_kwh`, prices, and amounts cannot be negative.
5. SOC values remain between 0 and 100.
6. Session `end_at` cannot precede session `start_at`.
7. Completed sessions require a charging start and end.
8. A port connector must exist in the connector vocabulary.
9. Booking events must follow the allowed state machine.
10. Prediction `feature_cutoff` cannot be later than `prediction_origin`.
11. Prediction `prediction_for` cannot precede `prediction_origin` for these two models.
12. Synthetic and real dataset manifests cannot share the same snapshot identity.
13. A parking space cannot be assigned to overlapping active bookings.
14. Refund totals cannot exceed the captured payment amount after accounting for previous refunds.
15. Host settlement line items may reference only completed, financially settled sessions.
16. Completed-session `energy_kwh` must reconcile to `meter_end_kwh - meter_start_kwh` within a documented meter tolerance.
17. `charging_requests.trip_id` is required for route-planning requests and absent for other request types.
18. A status event's `charger_id` must be the parent of its `port_id`, and `ingested_at` cannot precede `observed_at`.

## 7. Required indexes

| Entity | Index |
| --- | --- |
| `businesses`, `chargers` | GiST index on PostGIS location |
| `zones` | GiST index on boundary and unique index on chosen H3 identifier |
| `charger_ports` | Index on `charger_id`, `connector_type_id`, and operational status |
| `availability_windows` | Index on `port_id`, `start_at`, `end_at` |
| `bookings` | Index on `port_id`, interval, and status; database-level overlap protection |
| `bookings` | Index on `parking_space_id`, interval, and status; parking overlap protection |
| `booking_events` | Index on `booking_id`, `created_at` |
| `charging_sessions` | Index on `port_id`, `arrived_at`, and status |
| `charger_status_events` | Index on `port_id`, `observed_at desc` |
| `charging_requests` | Index on `zone_id`, `requested_at` |
| `demand_buckets` | Primary key on zone, bucket start, and bucket size |
| `ml_predictions` | Index on model, entity, prediction time, and generated time |

## 8. Booking state machine

Normal path:

`PENDING -> HELD -> PAYMENT_PENDING -> CONFIRMED -> CHECKED_IN -> CHARGING -> COMPLETED`

Alternative terminal paths:

- `HELD -> EXPIRED`
- `PAYMENT_PENDING -> PAYMENT_FAILED`
- `CONFIRMED -> CANCELLED`
- `CONFIRMED -> NO_SHOW`
- `CHECKED_IN -> CANCELLED` only under an explicit operational rule

Every transition must document the actor, time, old state, new state, and reason.

## 9. Sponsor-ready boundaries

| Sponsor | Database boundary |
| --- | --- |
| Google Maps / Google for Developers | Routes and Places enrich requests; exact coordinates remain operational, while zones enter ML views |
| Tavily | Discovers contextual or tariff sources; provenance and verification are stored before values become model inputs |
| Swytchcode | Governs external API calls and writes audit references, not business truth |
| n8n | Orchestrates alerts and scheduled jobs; it does not own booking state |
| Render | Hosts PostgreSQL/PostGIS, Redis, FastAPI, and workers later |
| Gemini / Lyzr | Consume typed prediction outputs and approved tools; they cannot alter numeric model outputs |
| CodeMate AI | Assists schema and test review; generated code still requires team review |

## 10. Implementation order after design approval

1. Create lookup enums and connector vocabulary.
2. Create identity, vehicle, zone, business, and amenity tables.
3. Create charger, port, hours, exceptions, and availability tables.
4. Create request and recommendation-impression instrumentation.
5. Create booking, parking, event, session, payment, refund, settlement, review, notification, and audit tables.
6. Add constraints and indexes.
7. Create analytics tables and snapshot manifests.
8. Add migrations and database tests.
9. Build synthetic data against the same logical contracts without mixing it into production truth.
