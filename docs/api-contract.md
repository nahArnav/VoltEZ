# VoltEZ API Contract

> Shared contract between backend, web and mobile teams.
> All endpoints are versioned under `/api/v1`.
> Changes to request/response shapes must update this file.

---

## Standard Error Response

All error responses follow this shape:

```json
{
  "code": "SLOT_UNAVAILABLE",
  "message": "The requested slot is no longer available.",
  "request_id": "uuid-string",
  "field_errors": [
    { "field": "start_at", "message": "Must be in the future" }
  ]
}
```

- `code`: Machine-readable error code (UPPER_SNAKE_CASE)
- `message`: Human-readable description
- `request_id`: Correlates with `X-Request-ID` header
- `field_errors`: Optional, present only for validation errors

---

## Authentication

All authenticated endpoints require `Authorization: Bearer <access_token>` header.

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/auth/register` | Public | Register new user (driver/owner) |
| POST | `/auth/verify` | Public | Verify OTP/email |
| POST | `/auth/login` | Public | Login, returns access + refresh tokens |
| POST | `/auth/refresh` | Refresh Token | Rotate refresh token, issue new access token |
| POST | `/auth/logout` | Bearer | Revoke refresh token |

---

## Driver / Users

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/users/me` | Bearer | Get current user profile |
| PATCH | `/users/me` | Bearer | Update current user profile |
| POST | `/vehicles` | Bearer (Driver) | Add a vehicle |
| GET | `/vehicles` | Bearer (Driver) | List user's vehicles |
| GET | `/vehicles/{id}` | Bearer (Driver) | Get vehicle details |
| PATCH | `/vehicles/{id}` | Bearer (Driver) | Update vehicle |
| DELETE | `/vehicles/{id}` | Bearer (Driver) | Remove vehicle |

---

## Business / Owner

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/businesses` | Bearer (Owner) | Create business profile |
| GET | `/businesses/{id}` | Bearer | Get business details |
| PATCH | `/businesses/{id}` | Bearer (Owner) | Update business |
| GET | `/businesses/{id}/analytics` | Bearer (Owner) | Business analytics dashboard |
| GET | `/businesses/{id}/recommendations` | Bearer (Owner) | AI availability/pricing recommendations |

---

## Chargers

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/chargers` | Bearer (Owner) | Create charger under a business |
| GET | `/chargers/nearby` | Bearer | Geospatial search (lat, lng, radius) |
| GET | `/chargers/{id}` | Bearer | Get charger details + ports + status |
| PATCH | `/chargers/{id}` | Bearer (Owner) | Update charger |
| DELETE | `/chargers/{id}` | Bearer (Owner) | Remove charger |
| POST | `/chargers/{id}/ports` | Bearer (Owner) | Add port to charger |
| PATCH | `/ports/{id}` | Bearer (Owner) | Update port |
| POST | `/ports/{id}/availability` | Bearer (Owner) | Create availability window |
| GET | `/ports/{id}/availability` | Bearer | List availability windows |
| PATCH | `/availability/{id}` | Bearer (Owner) | Update availability window |

---

## Routes & Recommendations

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/routes/recommendations` | Bearer (Driver) | Get ranked charging stop recommendations |
| POST | `/routes/quote` | Bearer (Driver) | Get detailed quote for a specific charger+slot |

---

## Bookings

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/bookings/hold` | Bearer (Driver) | Create hold on a slot (Redis lock + DB) |
| POST | `/bookings/{id}/confirm` | Bearer (Driver) | Confirm after payment verification |
| POST | `/bookings/{id}/cancel` | Bearer (Driver/Owner) | Cancel booking |
| GET | `/bookings/{id}` | Bearer | Get booking details |
| GET | `/bookings` | Bearer | List user's bookings |

---

## Charging Sessions

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/sessions/{booking_id}/check-in` | Bearer (Driver) | Check in at charger |
| POST | `/sessions/{id}/start` | Bearer (Driver) | Start charging |
| POST | `/sessions/{id}/complete` | Bearer (Driver) | Complete session |
| POST | `/sessions/{id}/report-issue` | Bearer (Driver) | Report issue with charger |

---

## Payments

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/payments/create-order` | Bearer (Driver) | Create payment order (sandbox) |
| POST | `/payments/verify` | Bearer (Driver) | Verify payment server-side |
| POST | `/payments/webhook` | Provider Signature | Payment provider callback |
| POST | `/payments/{id}/refund` | Bearer (Admin/Owner) | Initiate refund |

---

## ML / Intelligence (Internal)

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/ml/predictions/{entity_id}` | Internal/Admin | Get predictions for entity |
| GET | `/ml/health` | Internal/Admin | Model health and metrics |

---

## System

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| GET | `/health/live` | Public | Liveness probe |
| GET | `/health/ready` | Public | Readiness probe |
| GET | `/version` | Public | Version + build info |
