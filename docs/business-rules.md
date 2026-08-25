# VoltEZ Business Rules

> Canonical reference for all business rules enforced by the backend.
> Frontend teams should not implement conflicting logic.

---

## User Roles & Access

| Role | Access Level |
|------|-------------|
| DRIVER | Book chargers, manage vehicles, view recommendations, manage own sessions |
| OWNER | Manage businesses, chargers, availability, view analytics, approve AI recommendations |
| ADMIN | Verify users/businesses, system management, override capabilities |

- Authorization is enforced in **backend dependencies**, never only in UI.
- Registration creates an **unverified** user. Verification flips `verification_status`.

---

## Booking State Machine

```
PENDING -> HELD -> PAYMENT_PENDING -> CONFIRMED
            |           |               |
            -> EXPIRED   -> FAILED       -> CANCELLED
                                         -> NO_SHOW
                                         -> CHECKED_IN
                                              |
                                           CHARGING
                                              |
                                           COMPLETED
```

---

## Booking Business Rules

| Rule ID | Rule |
|---------|------|
| BR-001 | Vehicle connector must match charger port connector. |
| BR-002 | Vehicle must be able to reach the charger with reserve margin. |
| BR-003 | Confirmed/held bookings for the same port cannot overlap. |
| BR-004 | A booking hold expires after a short TTL (e.g., 5 minutes). |
| BR-005 | Payment must be verified server-side before confirmation. |
| BR-006 | Owner cannot delete/alter a window that would invalidate a confirmed booking without an explicit cancellation workflow. |
| BR-007 | Check-in allowed only inside configured early/late tolerance. |
| BR-008 | State transitions are validated centrally; clients cannot set arbitrary status. |
| BR-009 | Every transition writes to `booking_events`. |
| BR-010 | Create booking/payment/refund endpoints support idempotency keys. |

---

## Reservation Flow (Exact Sequence)

1. Client requests a **quote** for port + slot. Backend rechecks compatibility, schedule, overlap and price.
2. Backend creates a **Redis lock** key scoped to port and slot using `SET NX` with TTL. If it fails, return `409 SLOT_UNAVAILABLE`.
3. Inside a DB transaction, create booking status `HELD` with `hold_expires_at` and quote snapshot.
4. Create sandbox payment order if payment is enabled; transition to `PAYMENT_PENDING`.
5. Client completes payment. Backend verifies provider signature/status; **never trust a client `success=true`**.
6. Inside a transaction, recheck booking hold and DB overlap constraint, then set `CONFIRMED`.
7. Delete/allow expiry of Redis lock. Confirmed booking is now protected by DB truth.
8. Celery task expires stale `HELD`/`PAYMENT_PENDING` records and releases inventory.
9. On cancellation, compute refund policy from timestamps, create refund asynchronously, and append event.

---

## Three Meanings of Availability

| Concept | Example | Storage |
|---------|---------|---------|
| Owner schedule | "Tuesday 14:00-17:00 is offered" | `availability_windows` |
| Live status | Port is AVAILABLE/OCCUPIED/OFFLINE/UNKNOWN | `charger_status_events` / current projection |
| Booking occupancy | "14:30-15:15 already reserved" | `bookings` |

These are **separate concerns** and must not be conflated.

---

## No-IoT Trust System

- Every status update records `source`: `OWNER`, `DRIVER_CHECKIN`, `DRIVER_CHECKOUT`, `BOOKING_DERIVED`, `ADMIN`, or future CPO/IoT.
- Assign source **confidence**. Recent checkout = high confidence; old owner self-report decays.
- Compute current status from newest valid signal plus active bookings.
- Track mismatches: driver arrives but charger unavailable, owner cancellation, failed session.
- Update `reliability_score` after completed/failed sessions. Use a **Bayesian-smoothed or weighted score** so a new charger is not unfairly 0% or 100%.
- Expose `last_updated_at` and `confidence` to clients. Show "Recently confirmed" rather than falsely claiming perfect real-time telemetry.

---

## Charger Onboarding Rules

- Owner enters address or drops a pin. Backend geocodes/validates coordinates and stores PostGIS point.
- Backend validates sane power/price ranges and prevents duplicate charger creation at same business unless explicitly confirmed.
- Owner defines recurring or one-off availability windows. Convert recurring schedules into queryable windows for the demo horizon.
- Owner can pause a charger; **pausing must not silently cancel existing confirmed bookings**.

---

## Driver Onboarding Rules

- Driver onboarding requires **at least one vehicle** before personalized recommendations.
- Vehicle data includes: make, model, battery capacity, connector types, max charging power, estimated range.

---

## Pricing Rules

- Owner sets `base_price` on charger and optional `price_override` on availability windows.
- AI may recommend price within **owner-configured floor/ceiling**. Model cannot arbitrarily set extreme prices.
- Owner explicitly accepts/edits/rejects pricing recommendations.

---

## Graceful Degradation

| Failure | Behavior |
|---------|----------|
| Maps API timeout | Show fallback message / cached nearby chargers |
| ML model unavailable | Deterministic wait/ranking fallback |
| Gemini/Lyzr unavailable | Hide explanation enhancement; booking still works |
| Redis unavailable | Fail reservation safely rather than risk double booking |
| Payment webhook delayed | Show pending and reconcile later |
| Stale charger status | Lower confidence and surface timestamp |
