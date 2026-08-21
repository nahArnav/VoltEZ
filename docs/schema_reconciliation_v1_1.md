# VoltEZ schema v1.1 reconciliation

Status: approved design input, implementation contract for the ML branch
Source: `VoltEZ_Database_Schema_v1_1.png`
Applies from: synthetic generator v1.1 and feature view v1

## Why this reconciliation exists

The database diagram is the backend source of truth. The synthetic generator writes Parquet
fixtures rather than PostgreSQL rows, so it uses explicit names such as `zone_id` instead of a
generic `id` where that makes joins safer. Apart from that naming convention and the lineage
columns listed below, generated public tables must preserve the same entity boundaries and
relationships as the application schema.

Every generated row also contains `simulation_run_id`. Derived analytics rows additionally
contain `source_snapshot_id`. These are ML-lab lineage fields, not application columns.

## Changes from the first generator contract

| Area | v1.1 decision | Reason |
| --- | --- | --- |
| Identity | Generate synthetic `users`; vehicles and requests reference `user_id` | Makes foreign keys match the application instead of using an unexplained driver-only ID |
| Connectors | Keep `connector_types` and `vehicle_connectors` normalized | Avoids inconsistent connector strings |
| Host schedule | Use recurring `business_hours` plus dated `business_hour_exceptions` | Lets holidays and exceptional closures be represented without rewriting weekly hours |
| Amenities/offers | Add their normalized tables | Supports host and recommendation features without JSON arrays |
| Charging supply | Ports reference chargers only; parking spaces reference chargers | Matches the v1.1 physical hierarchy |
| Prices | Generate time-bounded `tariffs`; do not keep charger price as the source of truth | A displayed or charged price must be reproducible for the booking time |
| Journey | Generate `trips` and `trip_charger_options` for route-planning requests | Preserves VoltEZ's journey-aware differentiator |
| Status | A status event records both observation time and ingestion time | Prevents a delayed report from leaking into an earlier prediction |
| Sessions | Add meter start/end readings and final amount | Allows energy and billing consistency checks |
| Demand analytics | Add search, request, booking, session, unserved, and occupancy measures | Separates demand from fulfilled demand and capacity |
| Availability labels | Use `available`, `unavailable`, or `unknown` explicitly | Unknown is a third state and is never coerced to unavailable |

## Two necessary additive application links

The diagram omits two relationships needed by product behavior. They are retained as explicit
v1.1 extensions:

1. `charging_requests.trip_id` is nullable and references `trips.id`. Without it, a journey and
   its charger options cannot be connected reliably to the demand request that launched the
   recommendation flow.
2. `bookings.parking_space_id` is nullable and references `parking_spaces.id`. Without it, the
   app cannot guarantee the separately promised parking resource or reject overlapping parking
   reservations.

Both links should be reviewed with the backend team before migrations are frozen.

## Point-in-time ML rules that override convenient shortcuts

- `chargers.reliability_score` may be shown by the application but is not accepted directly as a
  Model 2 feature. The feature builder recomputes a versioned, Bayesian-smoothed reliability
  value using only outcomes known by the prediction cutoff.
- `charger_ports.current_status` is a read projection, not historical evidence. Model 2 uses the
  latest `charger_status_events` row whose `ingested_at` is at or before the prediction cutoff.
- `analytics.availability_observations.booking_state` and `port_status` describe label context at
  the observed target time. They must not be fed back as prediction-origin features.
- `analytics.context_events.expected_impact` is usable only when the event was published and
  ingested before the cutoff. The first feature view therefore works without context data.
- `search_count` is diagnostic and is not added to `request_count`. A single charging intent may
  create both a search and a structured request, so summing them would double-count demand.

## Duplicate status table in the diagram

`charger_status_events` is shown in both “Charging infrastructure” and “Actual charging.” This is
one physical append-only table viewed from two domains, not two database tables.

## ML-relevant v1.1 table groups

The generator materializes the tables required to build and validate the first two models:

- identity and compatibility: `users`, `vehicles`, `connector_types`, `vehicle_connectors`;
- geography and hosts: `zones`, `businesses`, schedules, amenities, offers;
- supply: `chargers`, `charger_ports`, `parking_spaces`, `availability_windows`, `tariffs`;
- demand and journey: `charging_requests`, `trips`, `trip_charger_options`,
  `recommendation_impressions`;
- outcomes: `bookings`, `booking_events`, `charging_sessions`, `charger_status_events`;
- analytics: `demand_buckets`, `availability_observations`, `context_events`;
- QA-only latent truth: tables prefixed `qa_latent_`.

Payments, refunds, settlements, notifications, reviews, and audit events remain application
tables but are not fabricated merely to increase row count. They can be added to a later
end-to-end backend fixture generator and are not inputs to Models 1 or 2.
