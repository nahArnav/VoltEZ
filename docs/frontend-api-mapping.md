# VoltEZ Frontend ↔ Backend API Mapping

> Verified against the current `final-frontend` checkout on 2026-08-30. The
> backend in `backend/` is the source of truth; UUIDs and trailing slashes in
> this document are intentional. Re-run this audit after changing either side.

The live Flutter dependency-injection root is wired to `ApiService`,
`LiveBookingApi`, `LiveSessionApi`, `LiveSessionWebSocket`, and
`LiveRouteRecommendationApi`. The `Mock*` classes listed near the end are
test fixtures only and are not used by `lib/main.dart`.

---

## Authentication

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.register()` | `POST /api/v1/auth/register` | POST | `{ name, email, password, role: "driver"/"owner", phone? }` | `UserResponse { id: UUID, name, email, phone?, role, verification_status, created_at }` | Public |
| `ApiService.login()` | `POST /api/v1/auth/login` | POST | `{ email, password }` | `TokenResponse { access_token, refresh_token, token_type }` | Public |
| `ApiService.refreshTokens()` | `POST /api/v1/auth/refresh` | POST | `{ refresh_token }` | `TokenResponse` | Refresh Token |
| `ApiService.logout()` | `POST /api/v1/auth/logout` | POST | — | — | Bearer |

## Users

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.getMe()` | `GET /api/v1/users/me` | GET | — | `UserResponse { id: UUID, name, email, phone?, role, verification_status, created_at }` | Bearer |
| `ApiService.updateMe()` | `PATCH /api/v1/users/me` | PATCH | `{ name?, phone? }` | `UserResponse` | Bearer |

## Vehicles

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.createVehicle()` | `POST /api/v1/vehicles/` | POST | `{ make, model, vehicle_class, battery_kwh, connector_type_ids: [1], max_ac_kw?, max_dc_kw?, estimated_range_km? }` | `VehicleResponse` | Bearer (Driver) |
| `ApiService.getVehicles()` | `GET /api/v1/vehicles/` | GET | — | `List<VehicleResponse>` | Bearer (Driver) |
| `ApiService.getVehicle()` | `GET /api/v1/vehicles/{id}` | GET | — | `VehicleResponse` | Bearer (Driver) |
| `ApiService.updateVehicle()` | `PATCH /api/v1/vehicles/{id}` | PATCH | `{ make?, model?, vehicle_class?, battery_kwh?, connector_type_ids?, ... }` | `VehicleResponse` | Bearer (Driver) |
| `ApiService.deleteVehicle()` | `DELETE /api/v1/vehicles/{id}` | DELETE | — | — | Bearer (Driver) |

## Chargers

| Frontend Method | Backend Endpoint | Method | Request Body / Params | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.getNearbyChargers()` | `GET /api/v1/chargers/nearby` | GET | `?latitude=...&longitude=...&radius_meters=5000` | `List<ChargerResponse>` | Bearer |
| `ApiService.getChargerById()` | `GET /api/v1/chargers/{id}` | GET | — | `ChargerResponse` with nested `ports` | Bearer |

### ChargerResponse Schema
```json
{
  "id": "UUID",
  "business_id": "UUID",
  "name": "Phoenix Mall Charger",
  "power_kw": 60.0,
  "access_type": "public",
  "base_price": 14.0,
  "status": "available",
  "reliability_score": 92.0,
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
| `ApiService.getRouteRecommendations()` | `POST /api/v1/recommendations/` | POST | `{ latitude, longitude, destination_latitude?, destination_longitude?, radius_meters, vehicle_id, current_soc, target_soc, reserve_soc, preferences? }` | `RecommendationResponse { recommendations[] }` | Bearer (Driver) |

## Bookings

| Frontend Method | Backend Endpoint | Method | Request Body | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.createBooking()` | `POST /api/v1/bookings/` | POST | `{ charger_port_id: UUID, start_at: datetime, end_at: datetime }` | Held `BookingResponse` | Bearer (Driver) |
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
| `ApiService.createPaymentOrder()` | `POST /api/v1/payments/create-order` | POST | `{ booking_id, method: "upi"|"card"|"cash" }` | `PaymentResponse` (`provider: stripe` when configured, otherwise Razorpay) | Bearer (Driver) |
| `ApiService.verifyPayment()` | `POST /api/v1/payments/verify` | POST | `{ provider_order_id, provider_payment_id, ... }` | `PaymentResponse` | Bearer (Driver) |
| `ApiService.verifyStripePayment()` | `POST /api/v1/payments/stripe/verify` | POST | `{ booking_id, checkout_session_id }` | `PaymentResponse` | Bearer (Driver) |
| Stripe webhook | `POST /api/v1/payments/stripe/webhook` | POST | Signed Stripe event | `{ status: "ok" }` | Stripe signature |

### Payment Status Values
```
pending | completed | failed | refunded
```

## Location search and notifications

| Frontend Method | Backend Endpoint | Method | Request | Response | Auth |
|---|---|---|---|---|---|
| `ApiService.searchLocations()` | `GET /api/v1/locations/search` | GET | `q`, `limit` | `LocationSearchResult[]` | Public geocoder proxy |
| `ApiService.getNotifications()` | `GET /api/v1/users/me/notifications` | GET | — | `NotificationResponse[]` | Bearer |
| `ApiService.markNotificationRead()` | `PATCH /api/v1/users/me/notifications/{id}` | PATCH | `{ status: "read" }` | `NotificationResponse` | Bearer |

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

## Optional/admin endpoints and compatibility methods

| Endpoint | Status |
|---|---|
| `POST /recommendations/` | Implemented and wired through `LiveRouteRecommendationApi` |
| `POST /routes/quote` | Not part of the current backend contract |
| `GET /bookings/{id}` | Implemented and used after payment verification |
| `POST /bookings/{id}/confirm` | Compatibility method; payment verification confirms payment atomically |
| `POST /payments/webhook` | Provider callback, no frontend needed |
| `POST /payments/{id}/refund` | Admin only |
| `POST /sessions/{id}/report-issue` | Implemented and wired |
| `GET /analytics/businesses/{id}/dashboard` | Implemented and wired to the owner dashboard |
| `GET /analytics/businesses/{id}/recommendations` | Implemented; optional insight panel |

---

## Test-only fixtures (not runtime data)

These adapters remain for widget/unit tests and offline UI development. They
must not be enabled in a production build:

| Mock Adapter | Purpose | Location |
|---|---|---|
| `MockBookingApi` | Booking flow (slots, hold, payment, confirm) | `lib/core/network/booking_api.dart` |
| `MockSessionApi` | Charging session (check-in, status, end, rating) | `lib/core/network/session_api.dart` |
| `MockSessionWebSocket` | Real-time session updates via WebSocket | `lib/core/network/session_websocket.dart` |
| `MockRouteRecommendationApi` | Route planner recommendations | `lib/core/network/route_recommendation_api.dart` |
| `ChargerDiscoveryProvider` | No mock loader in the production provider; nearby data comes from `/chargers/nearby` | `lib/core/providers/charger_discovery_provider.dart` |
| `RoutePlannerProvider.availableVehicles` | Runtime list populated from `/vehicles/`; it is not a fixture | `lib/core/providers/route_planner_provider.dart` |

`lib/main.dart` already wires the live adapters. Do not replace them with the
test fixtures when preparing a release.
