# VoltEZ Business Dashboard — Developer Guide

> **For Person 2 (Business Side)**  
> This guide covers the full codebase context you need to build the business owner experience in VoltEZ Flutter.

> **Current-branch note (2026-08-30):** This document began as an early
> handoff and some examples below describe the pre-integration/mock state.
> For the current live API, database, ML, Compose, and phone workflow, use
> [`docs/DEPLOYMENT_AND_PHONE_TESTING.md`](docs/DEPLOYMENT_AND_PHONE_TESTING.md),
> [`docs/frontend-api-mapping.md`](docs/frontend-api-mapping.md), and the
> backend/ML documentation index. Do not copy the legacy mock adapters or old
> integer-ID examples into new code.

---

## Table of Contents

1. [Project Structure](#1-project-structure)
2. [Tech Stack & Conventions](#2-tech-stack--conventions)
3. [Authentication & Role System](#3-authentication--role-system)
4. [Backend API Reference (Business-Relevant)](#4-backend-api-reference)
5. [Database Schemas (Pydantic → Dart)](#5-database-schemas)
6. [Existing Business Screens](#6-existing-business-screens)
7. [Design System & Theme](#7-design-system--theme)
8. [Routing & Navigation](#8-routing--navigation)
9. [State Management Pattern](#9-state-management-pattern)
10. [Booking Status Machine](#10-booking-status-machine)
11. [What's Already Built (Driver Side)](#11-whats-already-built-driver-side)
12. [What You Need to Build](#12-what-you-need-to-build)
13. [Backend Endpoints That Don't Exist Yet](#13-backend-endpoints-that-dont-exist-yet)
14. [Common Pitfalls](#14-common-pitfalls)

---

## 1. Project Structure

```
lib/
├── app.dart                              # MaterialApp setup
├── main.dart                             # Entry point, Provider setup
├── core/
│   ├── auth/auth_provider.dart           # JWT auth state (login, token refresh, role)
│   ├── network/
│   │   ├── api_service.dart              # Dio HTTP client (BASE_URL, interceptors)
│   │   ├── business_api.dart             # Business API adapter (MOCK — you replace this)
│   │   ├── booking_api.dart              # Booking API adapter (MOCK)
│   │   ├── session_api.dart              # Session API adapter (MOCK)
│   │   └── razorpay_service.dart         # Razorpay payment wrapper
│   ├── routing/app_router.dart           # GoRouter config (all routes)
│   └── theme/
│       ├── colors.dart                   # AppColors (MUST use these)
│       ├── typography.dart               # Text styles
│       └── app_theme.dart                # ThemeData
├── features/
│   ├── auth/                             # Login, splash, role selection
│   ├── driver/                           # ← Person 1 built this (reference)
│   └── business/                         # ← YOUR DOMAIN
│       ├── dashboard/dashboard_screen.dart
│       ├── chargers/
│       │   ├── charger_management_screen.dart
│       │   └── port_details_screen.dart
│       ├── availability/
│       │   └── availability_scheduler_screen.dart
│       ├── bookings/                     # Empty — you build this
│       ├── profile/                      # Empty — you build this
│       ├── onboarding/                   # Empty — you build this
│       └── analytics/                    # Empty — you build this
├── shared/
│   ├── models/models.dart                # ALL shared data models (User, Charger, Booking, etc.)
│   └── widgets/                          # Reusable widgets (VoltAppBar, StatusChip, etc.)
└── screens/                              # Legacy screens (older version — use features/ instead)
```

**Key rule:** Business screens live under `lib/features/business/`. The `lib/screens/` directory is legacy — don't add new files there.

---

## 2. Tech Stack & Conventions

| Area | Choice | Notes |
|---|---|---|
| Framework | Flutter (Dart) | Target: Android, iOS, Web |
| Routing | `go_router` | `context.go('/path')` to navigate, `context.pop()` to go back |
| State | `provider` (ChangeNotifier) | Wrap with `ChangeNotifierProvider` in `main.dart` |
| HTTP | `dio` | Configured in `api_service.dart` with JWT interceptors |
| Theme | Custom dark theme | Use `AppColors` from `lib/core/theme/colors.dart` |
| Currency | INR (₹) | All prices in Indian Rupees |
| ID type | `int` | All backend IDs are integers |
| Null safety | Full Dart 3 | Use `?` for optional fields |

**Naming conventions:**
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/methods: `camelCase`
- Backend JSON keys: `snake_case` (match exactly)

---

## 3. Authentication & Role System

### How it works

```
User registers with role: "DRIVER" | "OWNER"
    ↓
Login → receives access_token + refresh_token (JWT)
    ↓
auth_provider.dart stores tokens in SharedPreferences
    ↓
Dio interceptor adds "Authorization: Bearer <token>" to all requests
    ↓
If 401 → tries token refresh → if refresh fails → logout
    ↓
App router redirects based on role:
  OWNER → /business/dashboard
  DRIVER → /driver/home
```

### Key files

- `lib/core/auth/auth_provider.dart` — manages login state, tokens, user role
- `lib/core/network/api_service.dart` — Dio client with auto-refresh interceptor
- `lib/core/routing/app_router.dart` — redirect logic based on role

### Registration endpoint

```json
POST /api/v1/auth/register
{
  "name": "ABC Motors",
  "email": "owner@example.com",
  "password": "secret123",
  "role": "OWNER",          // ← MUST be "OWNER" for business users
  "phone": "+919876543210"  // optional
}
```

### Login endpoint

```json
POST /api/v1/auth/login
{
  "email": "owner@example.com",
  "password": "secret123"
}

Response:
{
  "access_token": "eyJ...",
  "refresh_token": "eyJ...",
  "token_type": "bearer"
}
```

### Getting user info after login

```dart
// In auth_provider.dart, after login:
final response = await _api.getMe();  // GET /api/v1/users/me
_user = User.fromJson(response.data);
```

---

## 4. Backend API Reference

> All endpoints are under `http://localhost:3000/api/v1/`  
> Authentication: `Authorization: Bearer <access_token>` header

### Auth Endpoints

| Method | Endpoint | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/auth/register` | Public | `UserCreate` | `UserResponse` |
| POST | `/auth/login` | Public | `UserLogin` | `TokenResponse` |
| POST | `/auth/refresh` | Refresh Token | `TokenRefresh` | `TokenResponse` |

### User Endpoints

| Method | Endpoint | Auth | Request | Response |
|---|---|---|---|---|
| GET | `/users/me` | Bearer | — | `UserResponse` |
| PATCH | `/users/me` | Bearer | `UserUpdate` | `UserResponse` |

### Business Endpoints

> ⚠️ **These endpoints are defined in the backend schemas but NOT yet implemented as API routes.**  
> You'll need to either:
> - Wait for backend to add these routes
> - Build with mock data using the adapter pattern (see below)

### Charger Endpoints (Owner-owned)

| Method | Endpoint | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/chargers/` | Bearer (OWNER/ADMIN) | `ChargerCreate` | `ChargerResponse` |
| GET | `/chargers/nearby` | Public | `?latitude&longitude&radius_meters` | `List<ChargerResponse>` |
| GET | `/chargers/{id}` | Bearer | — | `ChargerResponse` |

### Booking Endpoints

| Method | Endpoint | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/bookings/` | Bearer | `BookingCreate` | `BookingResponse` |
| POST | `/bookings/{id}/cancel` | Bearer | — | `BookingResponse` |

### Session Endpoints

| Method | Endpoint | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/sessions/check-in` | Bearer | `{ booking_id: int }` | `ChargingSessionResponse` |
| POST | `/sessions/{id}/start` | Bearer | — | `ChargingSessionResponse` |
| POST | `/sessions/{id}/complete` | Bearer | `{ energy_kwh: float }` | `ChargingSessionResponse` |

### Payment Endpoints

| Method | Endpoint | Auth | Request | Response |
|---|---|---|---|---|
| POST | `/payments/create-order` | Bearer | — | (Razorpay order) |
| POST | `/payments/verify` | Bearer | (Razorpay payload) | `PaymentResponse` |

---

## 5. Database Schemas

### UserResponse

```json
{
  "id": 1,
  "name": "ABC Motors",
  "email": "owner@example.com",
  "phone": "+919876543210",
  "role": "OWNER",              // "DRIVER" | "OWNER" | "ADMIN"
  "verification_status": "unverified",
  "created_at": "2026-08-18T10:00:00Z"
}
```

### BusinessResponse (backend schema exists, no API route yet)

```json
{
  "id": 1,
  "owner_id": 1,
  "name": "ABC Motors",
  "category": "mall",           // "mall" | "office" | "apartment"
  "address": "123 MG Road, Bangalore",
  "opening_hours": {
    "mon": {"open": "09:00", "close": "21:00"},
    "tue": {"open": "09:00", "close": "21:00"}
  },
  "verification_status": "verified",
  "latitude": 12.9716,
  "longitude": 77.5946,
  "created_at": "2026-08-18T10:00:00Z",
  "updated_at": "2026-08-18T10:00:00Z"
}
```

### ChargerResponse

```json
{
  "id": 1,
  "business_id": 1,
  "name": "Phoenix Mall Charger",
  "power_kw": 60.0,
  "access_type": "public",      // "public" | "private" | "restricted"
  "base_price": 14.0,           // INR per kWh
  "status": "active",           // "active" | "paused" | "inactive"
  "reliability_score": 0.94,    // 0.0 – 1.0
  "parking_info": "B2 Near Elevator",
  "amenities": "WiFi, Food, Restroom",   // comma-separated string
  "latitude": 12.9716,
  "longitude": 77.5946,
  "created_at": "2026-08-18T10:00:00Z",
  "updated_at": "2026-08-18T10:00:00Z",
  "ports": [
    {
      "id": 1,
      "charger_id": 1,
      "connector_type": "CCS2",       // string, NOT enum
      "max_power_kw": 60.0,
      "status": "available",          // "available" | "occupied" | "offline" | "unknown"
      "created_at": "2026-08-18T10:00:00Z"
    }
  ]
}
```

### ChargerCreate (what you send when adding a charger)

```json
{
  "business_id": 1,
  "name": "New Charger",
  "power_kw": 60.0,
  "access_type": "public",
  "base_price": 14.0,
  "status": "active",
  "parking_info": "Floor 2",
  "amenities": "WiFi, Restroom",
  "latitude": 12.9716,
  "longitude": 77.5946
}
```

### AvailabilityWindowResponse

```json
{
  "id": 1,
  "port_id": 1,
  "start_at": "2026-08-25T09:00:00Z",
  "end_at": "2026-08-25T11:00:00Z",
  "source": "owner",              // "owner" | "ai_recommendation" | "admin"
  "price_override": 18.0,         // null = use charger's base_price
  "status": "active",             // "active" | "paused" | "cancelled"
  "is_recurring": false,
  "recurrence_rule": "RRULE:FREQ=WEEKLY;BYDAY=TU,TH",
  "created_at": "2026-08-18T10:00:00Z"
}
```

### AvailabilityWindowCreate (what you send)

```json
{
  "port_id": 1,
  "start_at": "2026-08-25T14:00:00Z",
  "end_at": "2026-08-25T16:00:00Z",
  "source": "owner",
  "price_override": 20.0,
  "status": "active",
  "is_recurring": true,
  "recurrence_rule": "RRULE:FREQ=WEEKLY;BYDAY=TU,TH"
}
```

### BookingResponse

```json
{
  "id": 1,
  "user_id": 2,
  "vehicle_id": 1,
  "port_id": 1,
  "start_at": "2026-08-25T10:00:00Z",
  "end_at": "2026-08-25T11:00:00Z",
  "status": "CONFIRMED",          // see Booking Status Machine below
  "hold_expires_at": null,
  "quote_snapshot": {
    "price_per_kwh": 14.0,
    "estimated_kwh": 30.0,
    "estimated_total": 420.0
  },
  "idempotency_key": "abc-123",
  "created_at": "2026-08-25T09:45:00Z",
  "updated_at": "2026-08-25T09:45:00Z"
}
```

### ChargingSessionResponse

```json
{
  "id": 1,
  "booking_id": 1,
  "check_in_at": "2026-08-25T10:02:00Z",
  "start_at": "2026-08-25T10:05:00Z",
  "end_at": "2026-08-25T10:35:00Z",
  "energy_kwh": 28.5,
  "final_amount": 399.0,
  "status": "completed",          // "checked_in" | "charging" | "completed" | "failed"
  "created_at": "2026-08-25T10:02:00Z"
}
```

### PaymentResponse

```json
{
  "id": 1,
  "booking_id": 1,
  "amount": 420.0,
  "currency": "INR",
  "status": "completed",          // "pending" | "completed" | "failed" | "refunded"
  "provider_order_id": "order_abc123",
  "provider_payment_id": "pay_xyz789",
  "verified_at": "2026-08-25T09:50:00Z",
  "created_at": "2026-08-25T09:48:00Z"
}
```

### ReviewResponse

```json
{
  "id": 1,
  "session_id": 1,
  "user_id": 2,
  "rating": 4.5,
  "comment": "Great charger, fast charging",
  "issue_flags": ["charger_broken"],    // optional tags
  "created_at": "2026-08-25T11:00:00Z"
}
```

### NotificationResponse

```json
{
  "id": 1,
  "user_id": 1,
  "type": "booking_confirmed",     // "booking_confirmed" | "session_reminder" | "hold_expiring"
  "payload": {"booking_id": 1},
  "status": "sent",                // "pending" | "sent" | "failed" | "read"
  "created_at": "2026-08-25T09:45:00Z"
}
```

---

## 6. Existing Business Screens

### Dashboard (`dashboard_screen.dart`) — ✅ BUILT, MOCK DATA

The main business hub. Currently 100% hardcoded mock data.

**Bottom nav tabs:**
1. **Home** — Stats, charger list, bookings, utilization chart, AI insight
2. **Chargers** → `ChargerManagementScreen`
3. **Bookings** — Placeholder ("Coming soon")
4. **Analytics** — Placeholder ("Coming soon")
5. **Profile** — Placeholder ("Coming soon")

**What's hardcoded:**
- Business name: "ABC Motors"
- Stats: 8 active chargers, 24 bookings, ₹18.4K revenue, 76% utilization
- Chargers: 3 hardcoded chargers with names, power, status, reliability
- Bookings: 3 hardcoded booking rows
- Utilization chart: 7 hardcoded daily bars
- AI Insight: hardcoded text about Charger 03

### Charger Management (`charger_management_screen.dart`) — ✅ BUILT, MOCK DATA

Lists all chargers with status, power, price, reliability, amenities.

**What's hardcoded:**
- 3 chargers with all data
- Status toggling (pause/resume) — only local state, no API call

**Navigation:** Tapping "Details" opens `PortDetailsScreen`

### Port Details (`port_details_screen.dart`) — ✅ BUILT, MOCK DATA

Shows individual ports for a charger.

**What's hardcoded:**
- 4 ports with connector types, power, status
- Enable/disable toggling — only local state, no API call

### Availability Scheduler (`availability_scheduler_screen.dart`) — ✅ BUILT, MOCK DATA

Manages time slots for a port.

**What's hardcoded:**
- 2 existing slots
- "Create New Slot" form
- Repeat weekly toggle
- Price override slider
- "Save" button — only shows SnackBar, no API call

---

## 7. Design System & Theme

**Always use `AppColors` from `lib/core/theme/colors.dart`:**

```dart
import '../../../core/theme/colors.dart';

// Backgrounds
AppColors.background    // 0xFF0A0F1F — main background
AppColors.card          // 0xFF111827 — card background
AppColors.surface       // 0xFF1A2332 — slightly lighter

// Accents
AppColors.primary       // 0xFF00E5FF — Electric Cyan (main accent)
AppColors.secondary     // 0xFF3B82F6 — Ion Blue
AppColors.success       // 0xFF34D399 — Green
AppColors.warning       // 0xFFF59E0B — Amber
AppColors.error         // 0xFFEF4444 — Red

// Text
AppColors.textPrimary   // 0xFFF3F4F6 — White text
AppColors.textSecondary // 0xFF94A3B8 — Grey text
AppColors.textMuted     // 0xFF64748B — Dim text
```

**Style patterns from existing business screens:**

```dart
// Card container
Container(
  decoration: BoxDecoration(
    color: AppColors.card,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
  ),
)

// Status chip
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    color: statusColor.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(30),
  ),
  child: Text(status.toUpperCase(), style: TextStyle(...)),
)

// Section label
Row(children: [
  Text('01', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w800)),
  Expanded(child: Divider()),
  Text('SECTION TITLE', style: TextStyle(letterSpacing: 1.4, color: AppColors.textMuted)),
])
```

---

## 8. Routing & Navigation

### Business routes (from `app_router.dart`)

```dart
/business/dashboard      → DashboardScreen           ✅ Built
/business/chargers       → PlaceholderScreen          ⚠️ Needs real screen
/business/availability   → PlaceholderScreen          ⚠️ Needs real screen
/business/bookings       → PlaceholderScreen          ⚠️ Needs real screen
/business/analytics      → PlaceholderScreen          ⚠️ Needs real screen
/business/profile        → PlaceholderScreen          ⚠️ Needs real screen
```

### How to add a new route

1. Create your screen in `lib/features/business/your_feature/`
2. Import it in `lib/core/routing/app_router.dart`
3. Replace the `_PlaceholderScreen` with your real screen:

```dart
// In app_router.dart
GoRoute(
  path: '/business/bookings',
  builder: (context, state) => const BusinessBookingsScreen(),
),
```

### Navigation patterns

```dart
// Go to a route (replaces stack)
context.go('/business/dashboard');

// Push a route (adds to stack, back button works)
context.push('/business/chargers');

// Go back
context.pop();

// Go with data
context.push('/business/charger/$chargerId');

// Read route params
final chargerId = state.pathParameters['id'];
```

### VoltAppBar (reusable top bar)

```dart
import '../../../shared/widgets/volt_app_bar.dart';

VoltAppBar(
  title: 'Charger Fleet',
  // Optional: show back button (auto-handles empty stack)
  showBack: true,
)
```

---

## 9. State Management Pattern

The project uses `provider` + `ChangeNotifier`. Here's the pattern:

### 1. Create a provider

```dart
// lib/core/providers/charger_provider.dart
import 'package:flutter/foundation.dart';
import '../network/api_service.dart';
import '../../shared/models/models.dart';

class ChargerProvider extends ChangeNotifier {
  final ApiService _api;
  
  List<Charger> _chargers = [];
  bool _isLoading = false;
  String? _error;

  ChargerProvider({ApiService? api}) : _api = api ?? ApiService();

  List<Charger> get chargers => _chargers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadChargers(int businessId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.dio.get('/chargers/', queryParameters: {'business_id': businessId});
      _chargers = (response.data as List).map((j) => Charger.fromJson(j)).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
```

### 2. Register in main.dart

```dart
// In main.dart
ChangeNotifierProvider(
  create: (_) => ChargerProvider(),
),
```

### 3. Use in a screen

```dart
// In your screen
final provider = context.watch<ChargerProvider>();

if (provider.isLoading) return LoadingWidget();
if (provider.error != null) return ErrorDisplay(error: provider.error!);

return ListView.builder(
  itemCount: provider.chargers.length,
  itemBuilder: (ctx, i) => ChargerTile(charger: provider.chargers[i]),
);
```

---

## 10. Booking Status Machine

The backend defines these **exact** status values. Use them as-is:

```
PENDING → HELD → PAYMENT_PENDING → CONFIRMED → CHECKED_IN → CHARGING → COMPLETED
                ↓                                           ↓
              EXPIRED                                    FAILED
                ↓                                           ↓
             CANCELLED                                  CANCELLED
```

| Status | Meaning | Who transitions |
|---|---|---|
| `PENDING` | Booking created, awaiting hold | System |
| `HELD` | Time slot reserved, countdown started | System |
| `PAYMENT_PENDING` | Hold active, waiting for payment | System |
| `CONFIRMED` | Payment verified, booking locked in | Backend (after payment verify) |
| `CANCELLED` | User or admin cancelled | User / Admin |
| `EXPIRED` | Hold timer ran out without payment | System |
| `FAILED` | Payment or processing failure | System |
| `NO_SHOW` | Driver didn't check in by slot start | System |
| `CHECKED_IN` | Driver arrived at charger | Driver |
| `CHARGING` | Actively delivering power | Driver |
| `COMPLETED` | Session finished, energy delivered | Driver / System |

### Dart representation

```dart
// In lib/shared/models/models.dart
enum BookingStatus {
  PENDING, HELD, PAYMENT_PENDING, CONFIRMED, CANCELLED,
  EXPIRED, FAILED, NO_SHOW, CHECKED_IN, CHARGING, COMPLETED,
}

BookingStatus parseBookingStatus(String? status) {
  if (status == null) return BookingStatus.PENDING;
  return BookingStatus.values.firstWhere(
    (e) => e.name == status.toUpperCase(),
    orElse: () => BookingStatus.PENDING,
  );
}
```

**⚠️ Important:** The enum names are UPPER_CASE to match the backend JSON strings exactly. Don't rename them.

---

## 11. What's Already Built (Driver Side)

For reference, Person 1 has built:

| Screen | Route | Status |
|---|---|---|
| Driver Home | `/driver/home` | ✅ Live API + empty states |
| Station Map | `/driver/map` | ✅ OpenStreetMap + live chargers + place search |
| Route Planner Input | `/driver/route-planner` | ✅ Coordinate-backed place suggestions |
| Route Recommendations | `/driver/recommendations` | ✅ Live FastAPI/ML adapter |
| Charger Details | `/driver/charger/:id` | ✅ Live charger/port data |
| Booking (Slot Selection) | `/driver/booking` | ✅ Live availability + hold |
| Booking Confirmation | `/driver/booking-confirmation` | ✅ Server-confirmed |
| Payment | `/driver/payment` | ✅ Stripe Checkout preferred; Razorpay fallback |
| Charging Session | `/driver/session` | ✅ Live API/WebSocket adapter |
| Booking History | `/driver/history` | ✅ Live API |
| Driver Onboarding | `/driver/onboarding` | ✅ Create/edit vehicle setup |

The production screens use live adapters. Explicit `Mock*` classes remain only
as test fixtures and are not selected by `main.dart`.

---

## 12. What You Need to Build

### Priority 1 (Must Have)

| Screen | Route | Depends On |
|---|---|---|
| **Charger Management (real)** | `/business/chargers` | `POST /chargers/`, `GET /chargers/`, charger update |
| **Port Details (real)** | From charger list | `ChargerPort` data from charger response |
| **Availability Scheduler (real)** | From port details | `POST /availability-windows`, `GET /availability-windows` |
| **Business Bookings** | `/business/bookings` | `GET /bookings` (filtered by business) |
| **Business Profile** | `/business/profile` | `GET /users/me`, `PATCH /users/me` |

### Priority 2 (Should Have)

| Screen | Route | Depends On |
|---|---|---|
| **Analytics Dashboard** | `/business/analytics` | Aggregation endpoint (may not exist yet) |
| **Business Onboarding** | First-time setup | `POST /businesses` |
| **Notifications** | In-app | `GET /notifications` |

### Priority 3 (Nice to Have)

| Screen | Route | Depends On |
|---|---|---|
| Revenue reports | Within analytics | Aggregation |
| Pricing optimizer | AI insight cards | ML endpoint |
| Multi-business switcher | Profile | Multiple businesses |

---

## 13. Backend Endpoints That Don't Exist Yet

These are referenced in schemas but **have no API routes** in the current backend:

| Schema Exists | Endpoint Needed | For |
|---|---|---|
| `BusinessCreate/Response` | `POST /businesses`, `GET /businesses/me` | Business registration & profile |
| `ChargerUpdate` | `PATCH /chargers/{id}` | Edit charger details |
| `AvailabilityWindowCreate` | `POST /availability-windows` | Create time slots |
| `AvailabilityWindowUpdate` | `PATCH /availability-windows/{id}` | Edit/update slots |
| `BookingResponse` (list) | `GET /bookings` (owner-filtered) | Owner sees bookings for their chargers |
| `ReviewResponse` (list) | `GET /chargers/{id}/reviews` | See driver reviews |
| `NotificationResponse` (list) | `GET /notifications` | In-app notifications |
| Analytics aggregation | `GET /analytics/summary` | Dashboard stats |

**Strategy:** Build all screens with the `Mock*Api` adapter pattern. When the backend adds these endpoints, you swap the mock for the real implementation by changing one line in `main.dart`.

### How to build with mocks (the pattern Person 1 used)

```dart
// 1. Define the abstract API contract
abstract class BusinessChargerApi {
  Future<List<Charger>> getChargers(int businessId);
  Future<Charger> createCharger(ChargerCreate data);
  Future<Charger> updateCharger(int id, ChargerUpdate data);
}

// 2. Create the mock implementation
class MockBusinessChargerApi implements BusinessChargerApi {
  @override
  Future<List<Charger>> getChargers(int businessId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [/* hardcoded chargers */];
  }
  // ...
}

// 3. Create the live implementation (for when backend is ready)
class LiveBusinessChargerApi implements BusinessChargerApi {
  final Dio _dio;
  LiveBusinessChargerApi(this._dio);
  
  @override
  Future<List<Charger>> getChargers(int businessId) async {
    final resp = await _dio.get('/chargers/', queryParameters: {'business_id': businessId});
    return (resp.data as List).map((j) => Charger.fromJson(j)).toList();
  }
  // ...
}

// 4. In main.dart, swap mock for live:
ChangeNotifierProvider(
  create: (_) => BusinessChargerProvider(
    api: MockBusinessChargerApi(),  // ← swap to LiveBusinessChargerApi(api.dio) later
  ),
),
```

---

## 14. Common Pitfalls

### ❌ Don't hardcode status values in widgets

```dart
// BAD — status string might change
if (booking.status == 'active') { ... }

// GOOD — use the enum
if (booking.status == BookingStatus.CONFIRMED) { ... }
```

### ❌ Don't use `Navigator.push` — use GoRouter

```dart
// BAD
Navigator.push(context, MaterialPageRoute(builder: (_) => MyScreen()));

// GOOD
context.push('/business/chargers');
```

### ❌ Don't create a second Dio instance

```dart
// BAD — bypasses JWT interceptors
final dio = Dio(BaseOptions(baseUrl: 'http://localhost:3000'));

// GOOD — use the shared ApiService
final api = ApiService();
final resp = await api.dio.get('/chargers/');
```

### ❌ Don't mix mock data with real API responses

Keep them in separate adapter classes. Never write `if (kDebugMode) { return mockData; }` inside a provider.

### ❌ Don't use connector types as enums for comparison

```dart
// BAD — backend returns strings
if (port.connectorType == ConnectorType.ccs2) { ... }

// GOOD — compare strings
if (port.connectorType == 'CCS2') { ... }
```

### ❌ Don't forget the API version prefix

```dart
// BAD
await dio.get('/chargers/nearby');

// GOOD
await dio.get('/chargers/nearby');  // ApiService already prefixes /api/v1
```

### ❌ Don't display stale data as real-time

```dart
// BAD
Text('Live availability')

// GOOD — if data is from a non-realtime source
Text('Last updated: ${formatTime(charger.updatedAt)}')
```

### ✅ DO reuse existing models

The shared models in `lib/shared/models/models.dart` already handle `fromJson` for all backend schemas. Import and use them — don't create duplicate model classes.

### ✅ DO use `AppColors` constants

Don't define your own colors. The driver and business sides share the same palette.

### ✅ DO handle loading/error/empty states

Every screen should show:
- **Loading:** Skeleton or `CircularProgressIndicator`
- **Error:** Error message + retry button
- **Empty:** Friendly message ("No chargers yet. Add your first charger!")

---

## Quick Start Checklist

- [ ] Register as `OWNER` role via `/auth/register`
- [ ] Login → auto-redirect to `/business/dashboard`
- [ ] Replace mock dashboard data with real API calls
- [ ] Build charger CRUD screens with mock adapter
- [ ] Build availability scheduler with mock adapter
- [ ] Build bookings list screen
- [ ] Build business profile screen
- [ ] Add analytics placeholder
- [ ] Run `flutter analyze` — fix any errors
- [ ] Test end-to-end on Chrome: `flutter run -d chrome`

---

*Last updated: August 2026*
*Backend branch: `origin/Backend`*
*Frontend branch: `frontend-swarali`*
