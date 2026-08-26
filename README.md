# VoltEZ — Next-Gen EV Charging & Decision-Intelligence Platform

[![FastAPI](https://img.shields.io/badge/FastAPI-0.141+-009688?style=flat-square&logo=fastapi)](https://fastapi.tiangolo.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-PostGIS-336791?style=flat-square&logo=postgresql)](https://postgis.net)
[![Python](https://img.shields.io/badge/Python-3.12%20%7C%203.13-3776AB?style=flat-square&logo=python)](https://python.org)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Status](https://img.shields.io/badge/Audit-PASSED%20%26%20READY-brightgreen?style=flat-square)](#audit-verification--test-results)

VoltEZ is an end-to-end EV charging discovery, atomic reservation, session telemetry, and machine-learning decision-intelligence platform. It bridges driver mobile UX with commercial charger station owners through real-time geospatial search, route-energy physics math, dynamic demand forecasting, and zero-trust reliability scoring.

---

## 🏛️ System Architecture

```mermaid
flowchart TB
    subgraph Client Layer
        Mobile[Flutter App - Driver & Owner UI]
        ApiClient[ApiClient Singleton - Dio + Secure Storage]
        Mobile --> ApiClient
    end

    subgraph API & Web Layer
        FastAPI[FastAPI Backend Server - port 8000]
        WS[WebSocket Manager - Realtime Push]
        Router[API Router /api/v1]
        ApiClient -->|JWT Bearer REST| Router
        ApiClient -->|WS Connection| WS
        Router --> FastAPI
    end

    subgraph Service & Intelligence Layer
        AuthSvc[Auth Service - Argon2 + JWT]
        BookingSvc[Booking Service - Atomic Holds]
        SessionSvc[Session Telemetry Service]
        TrustSvc[No-IoT Trust System - Reliability Score]
        MLAdapter[ML Inference Adapter - Joblib Models]
        PhysicsEngine[Route-Energy Physics Calculator]
    end

    subgraph Data & Storage Layer
        Postgres[(PostgreSQL 16 + PostGIS Spatial Index)]
        Redis[(Redis Key-Value & ARQ Job Queue)]
        ModelStore[(ML Joblib Artifact Store)]
    end

    FastAPI --> AuthSvc
    FastAPI --> BookingSvc
    FastAPI --> SessionSvc
    FastAPI --> MLAdapter

    BookingSvc -->|Atomic Hold Lock| Redis
    BookingSvc --> DB[(Postgres)]
    SessionSvc --> TrustSvc
    TrustSvc --> DB
    MLAdapter --> ModelStore
    MLAdapter --> PhysicsEngine
    Router --> Postgres
```

---

## ⚡ Core Features & Key Workflows

### 🚗 EV Driver Flow
- **Geospatial Station Discovery**: Instant PostGIS radius search (`ST_DWithin`) filtering compatible connector types and active ports.
- **Route-Energy Physics Assessment**: Computes aerodynamic drag, rolling resistance, climbing elevation, and battery State of Charge (SoC) reserve to calculate real-world reachability before sending the driver to a charger.
- **Dynamic ML Wait-Time Prediction**: ML Model 2 predicts port occupancy probability at ETA and returns calibrated congestion levels (`LOW`, `MEDIUM`, `HIGH`).
- **Atomic 10-Minute Reservation Holds**: Prevents double-booking via Redis key locks (`set(lock_key, user_id, nx=True, ex=600)`). If unpaid, background ARQ workers automatically expire the slot.
- **Session Check-In & Telemetry**: Drivers check in upon arrival, track energy delivered (kWh), and complete sessions with server-side pricing verification.
- **No-IoT Trust System**: Drivers can report broken chargers, instantly penalizing station reliability scores by 20% to prevent bad recommendations for other users.
- **Razorpay Payment Integration**: Integrated order creation and HMAC-SHA256 signature verification webhooks.

### 🏢 Charger Station Owner Flow
- **Business Location Profiles**: Register commercial locations with PostGIS geography coordinates.
- **Charger & Port Management**: Dynamic station capacity configuration (AC/DC power kW ratings, connector types).
- **AI Intelligence & Dynamic Pricing**: ML Model 1 (Demand Forecasting) analyzes historical demand windows to recommend off-peak discounts or peak pricing strategies.
- **Live Notifications**: Real-time push updates via WebSockets and Firebase Cloud Messaging (FCM).

---

## 🤖 Machine Learning Intelligence Suite

| Track | Model Name | Algorithm | Features | Metrics / Performance | Deployment Stage |
| :--- | :--- | :--- | :---: | :--- | :--- |
| **Model 1** | Demand Forecasting | Histogram Gradient Boosting (Poisson) | 52 | **MAE 0.739**, RMSE 0.990, 75.89% within 1 request | `synthetic_validated` |
| **Model 2** | Charger Availability | Calibrated Histogram Gradient Boosting | 35 | **ROC-AUC 0.809**, 94.67% accuracy on binary decisions | `shadow` |
| **Model 3** | Waiting-Time Predictor | Quantile Regression | 35 | Calibrated queue wait estimation in minutes | `serving_ready` |
| **Model 4** | Reliability Score | Weighted Historical Evidence | 18 | No-IoT Bayesian reliability score (0-100) | `serving_ready` |
| **Model 5** | Route-Energy Physics | First-Principles Drag + Mass Solver | Native | Physics force equation for exact kWh reachability | `live_embedded` |

---

## 🛠️ Technology Stack

- **Backend Framework**: Python 3.12+ with [FastAPI](https://fastapi.tiangolo.com/) & Uvicorn
- **Database & Spatial**: PostgreSQL 16 with [PostGIS](https://postgis.net/) spatial index, SQLAlchemy 2.0 (AsyncIO), GeoAlchemy2
- **Cache & Async Worker Queue**: Redis 7 & [ARQ](https://github.com/samuelcolvin/arq)
- **Machine Learning**: `scikit-learn`, `joblib`, `pandas`, `numpy`, `polars`
- **Security & Auth**: Argon2 (`passlib`), PyJWT / `python-jose`, OAuth2 Bearer Tokens
- **Frontend App**: Flutter 3.x (Dart), Dio HTTP Client with automatic token refresh queue, FlutterSecureStorage

---

## 📊 Audit Verification & Test Results

An end-to-end architecture and integration audit was completed across all backend endpoints, database schemas, and frontend API services.

### 🔍 Verification Highlights
- **FastAPI Startup Verification**: `All Pydantic models & routes loaded successfully without warnings!` (**PASS**)
- **ML Physics & Prediction Suite**: `133 passed in 29.39s` (**100% PASS**)
- **Pydantic V2 Migration**: All response models updated to `model_config = ConfigDict(from_attributes=True)`.
- **Database Model Integrity**: All 24 SQLAlchemy ORM models verified and registered in `database/base.py`.

---

## 🚀 Quickstart & Installation Guide

### Prerequisites
- Python 3.12+
- PostgreSQL 16+ with PostGIS extension enabled (`CREATE EXTENSION postgis;`)
- Redis 7+
- Flutter SDK (for mobile app)

### 1. Backend Setup

```bash
# Clone the repository
git clone https://github.com/nahArnav/VoltEZ.git
cd VoltEZ/backend

# Create virtual environment and install dependencies
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\Activate.ps1
pip install -r requirements.txt

# Configure environment variables
copy .env.example .env
```

Ensure `.env` contains your PostgreSQL and Redis connections:
```env
PROJECT_NAME="VoltEZ API"
DATABASE_URL="postgresql+asyncpg://postgres:postgres@localhost:5432/voltez"
REDIS_URL="redis://localhost:6379/0"
SECRET_KEY="your-production-secret-key"
```

### 2. Run Database Migrations

```bash
# Run Alembic migrations to set up the app schema
cd VoltEZ
alembic upgrade head
```

### 3. Start API Server & Worker

```bash
# Start FastAPI backend (port 8000)
cd VoltEZ/backend
uvicorn app.main:app --reload --port 8000

# Start ARQ background worker (in a separate terminal)
arq app.worker.WorkerSettings
```

API Documentation will be live at:
- **Swagger UI**: [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc**: [http://localhost:8000/redoc](http://localhost:8000/redoc)

### 4. Frontend Mobile App Setup

```bash
cd VoltEZ

# Install Flutter dependencies
flutter pub get

# Run application locally
flutter run
```

---

## 📂 Project Structure

```
VoltEZ/
├── backend/
│   ├── app/
│   │   ├── api/v1/          # REST routes (auth, booking, charger, sessions, etc.)
│   │   ├── core/            # Config, security (Argon2/JWT), error handling
│   │   ├── db/              # Async SQLAlchemy session factory
│   │   ├── ml/              # ML adapters & feature pipeline builders
│   │   ├── repositories/    # Async CRUD repository pattern
│   │   ├── schemas/         # Pydantic V2 request & response schemas
│   │   ├── services/        # Business logic domain services
│   │   ├── websockets/      # Real-time WebSocket connection manager
│   │   ├── main.py          # FastAPI application entry point & lifespan
│   │   └── worker.py        # ARQ Redis background job worker
│   └── requirements.txt
├── database/
│   ├── models/              # SQLAlchemy 2.0 ORM DB Models (24 models)
│   ├── base.py              # Centralized Declarative Base model registry
│   └── session.py           # Sync DB connection session maker
├── lib/
│   ├── core/                # App config & environment constants
│   ├── models/              # Dart data models
│   ├── screens/             # Flutter UI screens (Explore, Bookings, Dashboard)
│   └── services/            # API Client singleton, Auth & Profile services
├── models/                  # Trained Joblib ML model bundles
├── src/voltez_ml/           # Core ML package (training, features, evaluation)
├── tests/                   # ML core test suite (133 unit tests)
├── alembic/                 # Database migration scripts
├── docker-compose.yml       # Infrastructure orchestration
└── README.md
```

---

## 📜 License & Author

Built with ❤️ by the VoltEZ Team for next-generation EV mobility.
