# VoltEZ Frontend ↔ Backend API Mapping

> Auto-generated audit document. All endpoints match the actual FastAPI backend
> from the `origin/Backend` branch. Backend is the source of truth.

---

## Authentication

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.register()` | `POST /api/v1/auth/register` | POST | `{ name, email, password, role: "DRIVER"/"OWNER", phone? }` | `UserResponse { id: int, name, email, phone?, role, verification_status, created_at }` | Public |
| `ApiService.login()` | `POST /api/v1/auth/login` | POST | `{ email, password }` | `TokenResponse { access_token, refresh_token, token_type }` | Public |
| `ApiService.refreshTokens()` | `POST /api/v1/auth/refresh` | POST | `{ refresh_token }` | `TokenResponse` | Refresh Token |
| `ApiService.logout()` | `POST /api/v1/auth/logout` | POST | — | — | Bearer |

## Users

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.getMe()` | `GET /api/v1/users/me` | GET | — | `UserResponse { id: int, name, email, phone?, role, verification_status, created_at }` | Bearer |
| `ApiService.updateMe()` | `PATCH /api/v1/users/me` | PATCH | `{ name?, phone? }` | `UserResponse` | Bearer |

## Vehicles

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.createVehicle()` | `POST /api/v1/vehicles` | POST | `{ make, model, battery_kwh, connector_types: ["CCS2"], max_ac_kw?, max_dc_kw?, estimated_range_km? }` | `VehicleResponse` | Bearer (Driver) |
| `ApiService.getVehicles()` | `GET /api/v1/vehicles` | GET | — | `List<VehicleResponse>` | Bearer (Driver) |
| `ApiService.getVehicle()` | `GET /api/v1/vehicles/{id}` | GET | — | `VehicleResponse` | Bearer (Driver) |
| `ApiService.updateVehicle()` | `PATCH /api/v1/vehicles/{id}` | PATCH | `{ make?, model?, battery_kwh?, connector_types?, ... }` | `VehicleResponse` | Bearer (Driver) |
| `ApiService.deleteVehicle()` | `DELETE /api/v1/vehicles/{id}` | DELETE | — | — | Bearer (Driver) |

## Chargers

| Frontend Method | Backend Endpoint | Method | Request Body / Params | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.getNearbyChargers()` | `GET /api/v1/chargers/nearby` | GET | `?latitude=...&longitude=...&radius_meters=5000` | `List<ChargerResponse>` | Public |
| `ApiService.getChargerById()` | `GET /api/v1/chargers/{id}` | GET | — | `ChargerResponse` with nested `ports` | Bearer |

### ChargerResponse Schema
```json
{
  "id": 1,
  "business_id": 1,
  "name": "Phoenix Mall Charger",
  "power_kw": 60.0,
  "access_type": "public",
  "base_price": 14.0,
  "status": "active",
  "reliability_score": 0.92,
  "latitude": 19.076,
  "longitude": 72.877,
  "amenities": "WiFi,Parking",
  "parking_info": "...",
  "ports": [
    {
      "id": 1,
      "charger_id": 1,
      "connector_type": "CCS2",
      "max_power_kw": 60.0,
      "status": "available"
    }
  ],
  "created_at": "...",
  "updated_at": "..."
}
```

## Routes & Recommendations

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.getRouteRecommendations()` | `POST /api/v1/routes/recommendations` | POST | `{ origin: {lat, lng, name?}, destination: {lat, lng, name?}, vehicle: {make, model, battery_kwh, connector_types}, current_soc, reserve_soc, preference }` | ⚠️ Not yet implemented in backend | Bearer (Driver) |

## Bookings

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.createBooking()` | `POST /api/v1/bookings/` | POST | `{ port_id: int, start_at: datetime, end_at: datetime, vehicle_id?: int, idempotency_key?: str }` | `BookingResponse` | Bearer (Driver) |
| `ApiService.confirmBooking()` | `POST /api/v1/bookings/{id}/confirm` | POST | — | `BookingResponse` | Bearer (Driver) |
| `ApiService.cancelBooking()` | `POST /api/v1/bookings/{id}/cancel` | POST | — | `BookingResponse` | Bearer (Driver) |
| `ApiService.getDriverBookings()` | `GET /api/v1/bookings` | GET | — | `List<BookingResponse>` | Bearer |
| `ApiService.getBooking()` | `GET /api/v1/bookings/{id}` | GET | — | `BookingResponse` | Bearer |

### BookingStatus Enum (Backend)
```
PENDING | HELD | PAYMENT_PENDING | CONFIRMED | CANCELLED | EXPIRED |
FAILED | NO_SHOW | CHECKED_IN | CHARGING | COMPLETED
```

## Payments

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.createPaymentOrder()` | `POST /api/v1/payments/create-order` | POST | `{ booking_id, amount, currency, provider_order_id? }` | `PaymentResponse` | Bearer (Driver) |
| `ApiService.verifyPayment()` | `POST /api/v1/payments/verify` | POST | `{ provider_order_id, provider_payment_id, ... }` | `PaymentResponse` | Bearer (Driver) |

### Payment Status Values
```
pending | completed | failed | refunded
```

## Charging Sessions

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.checkIn()` | `POST /api/v1/sessions/check-in` | POST | `{ booking_id: int }` | `ChargingSessionResponse` | Bearer (Driver) |
| `ApiService.startCharging()` | `POST /api/v1/sessions/{id}/start` | POST | — | `ChargingSessionResponse` | Bearer (Driver) |
| `ApiService.completeSession()` | `POST /api/v1/sessions/{id}/complete` | POST | `{ energy_kwh: float }` | `ChargingSessionResponse` | Bearer (Driver) |
| `ApiService.reportSessionIssue()` | `POST /api/v1/sessions/{id}/report-issue` | POST | `{ ... }` | — | Bearer (Driver) |

### Session Status Values
```
checked_in | charging | completed | failed
```

---

## Error Response Format

All backend errors follow:
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

### HTTP Status Codes Used
| Code | Meaning |
|---|---|
| 400 | Bad Request (validation, invalid state transition) |
| 401 | Unauthorized (missing/invalid token) |
| 403 | Forbidden (wrong role) |
| 404 | Not Found |
| 409 | Conflict (slot unavailable, overlap) |
| 422 | Validation Error |
| 500 | Internal Server Error |

---

## Known Backend Endpoints Not Yet Implemented in Frontend

| Endpoint | Status |
|---|---|
| `POST /routes/recommendations` | API contract defined, not implemented in backend |
| `POST /routes/quote` | API contract defined, not implemented in frontend |
| `GET /bookings/{id}` | Frontend has stub |
| `POST /bookings/{id}/confirm` | Frontend has stub |
| `POST /payments/webhook` | Provider callback, no frontend needed |
| `POST /payments/{id}/refund` | Admin only |
| `POST /sessions/{id}/report-issue` | Frontend has stub |
| `GET /businesses/{id}/analytics` | Frontend has stub |
| `GET /businesses/{id}/recommendations` | Owner AI recommendations |

---

## Current Frontend Mock Data Locations

All mock data is isolated behind clearly named adapter classes:

| Mock Adapter | Purpose | Location |
|---|---|---|
| `MockBookingApi` | Booking flow (slots, hold, payment, confirm) | `lib/core/network/booking_api.dart` |
| `MockSessionApi` | Charging session (check-in, status, end, rating) | `lib/core/network/session_api.dart` |
| `MockSessionWebSocket` | Real-time session updates via WebSocket | `lib/core/network/session_websocket.dart` |
| `MockRouteRecommendationApi` | Route planner recommendations | `lib/core/network/route_recommendation_api.dart` |
| `ChargerDiscoveryProvider._loadMockChargers()` | Nearby charger discovery | `lib/core/providers/charger_discovery_provider.dart` |
| `RoutePlannerProvider.availableVehicles` | Vehicle selection for route planner | `lib/core/providers/route_planner_provider.dart` |

### To switch to live backend:
Replace `Mock*` with `Live*` at the DI root in `lib/main.dart`.
