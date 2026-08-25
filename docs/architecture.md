# VoltEZ Architecture

## Architecture Decision: Modular Monolith

**Decision**: Use a modular monolith for the hackathon. One FastAPI backend is easier to ship, debug and demo than microservices.

**Rationale**: Keep strict internal boundaries (modules with clear interfaces) so modules can later split into microservices if needed. During the hackathon, the simplicity of a single deployable unit outweighs the benefits of distributed services.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                    CLIENTS                           │
│   Next.js Business Web        Flutter Driver App     │
│            \                     /                   │
│             \   REST + JWT      /                    │
└──────────────\────────────────/───────────────────────┘
                \              /
         ┌───────▼──────────▼────────┐
         │        FastAPI            │
         │   ┌──────┬────────┬────┐  │
         │   │ Auth │Booking │Intel│  │
         │   └──┬───┴───┬────┴──┬─┘  │
         │      │       │       │     │
         │      │  Redis Holds  │     │
         │      │       │    Demand/  │
         │      │       │    Wait ML  │
         │   ┌──▼───────▼───────▼──┐  │
         │   │ PostgreSQL/PostGIS  │  │
         │   └─────────────────────┘  │
         │   Celery/background jobs   │
         └────────────┬───────────────┘
                      │
    ┌─────────────────▼─────────────────────┐
    │         External Services              │
    │ Maps │ Payment │ n8n │ Tavily │        │
    │ Gemini/Lyzr │ Swytchcode              │
    └───────────────────────────────────────┘
```

---

## Module Boundaries

### Auth Module
- User registration, verification, login/logout
- JWT access + refresh token management
- Role-based authorization dependencies
- **Owns**: `users` table

### Booking Module
- Reservation lifecycle (hold → confirm → check-in → complete)
- Redis-based slot locking for concurrency
- State machine with audit trail
- Payment integration orchestration
- **Owns**: `bookings`, `booking_events`, `charging_sessions`, `payments` tables

### Intelligence Module
- Charger search and ranking
- Demand forecasting and wait prediction
- Route/reachability calculations
- Owner availability/pricing recommendations
- **Owns**: `demand_history`, `ml_predictions` tables

### Charger/Business Module
- Charger and port CRUD
- Availability window management
- No-IoT trust/reliability system
- Business onboarding and analytics
- **Owns**: `businesses`, `chargers`, `charger_ports`, `availability_windows`, `charger_status_events`, `reviews` tables

### Notification Module
- Async notifications (booking confirmations, reminders, etc.)
- **Owns**: `notifications` table

---

## Data Flow: Booking Path

```
Driver → POST /bookings/hold
  → Compatibility check (vehicle ↔ port)
  → Reachability check (SOC + range)
  → Redis SET NX (port:slot lock, 5min TTL)
  → DB transaction: create HELD booking
  → Return hold with expiry

Driver → POST /payments/create-order
  → Backend creates sandbox order
  → Transition to PAYMENT_PENDING

Driver → POST /bookings/{id}/confirm
  → Verify payment server-side
  → Recheck overlap in DB transaction
  → Set CONFIRMED, release Redis lock
  → Celery: schedule expiry cleanup
```

---

## Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| API Framework | FastAPI | Async Python web framework |
| Database | PostgreSQL 16 + PostGIS 3.4 | Relational + geospatial |
| Cache/Locks | Redis 7 | Booking slot locks, caching |
| Task Queue | Celery | Background jobs (expiry, notifications) |
| ORM | SQLAlchemy 2 (async) | Database access |
| Migrations | Alembic | Schema versioning |
| Auth | python-jose (JWT) + Argon2 | Tokens + password hashing |
| HTTP Client | httpx | External API calls |
| Geospatial | GeoAlchemy2 | PostGIS integration |
| Testing | pytest + pytest-asyncio | Unit + integration tests |

---

## Adapter Pattern for External Services

All external service integrations use an adapter/interface pattern:

```python
class MapsProvider:
    async def geocode(...)
    async def route(...)
    async def matrix(...)

class PaymentProvider:
    async def create_order(...)
    async def verify(...)
    async def refund(...)

class SearchProvider:
    async def search(...)

class AgentProvider:
    async def explain_recommendation(...)
```

Services depend on interfaces, not vendor SDKs directly. This allows:
- Swapping vendors (Google Maps ↔ Mapbox)
- Feature flags for sponsor integrations
- Graceful degradation when external APIs are unavailable

---

## Key Principle

> External intelligence enhances the system; PostgreSQL + deterministic business rules remain truth.
