# VoltEZ deployment and phone testing

This guide applies to the `final-frontend` branch. It describes the checked-in
Compose deployment, the local web build, and the native phone prerequisites.

## What is verified in this branch

- Backend unit/contract suite: 136 tests passed with integration tests excluded.
- Python compilation, fatal Ruff checks, and a single Alembic head: passed.
- Flutter static analyzer: 0 issues found.
- Dynamic pricing bounds and tariff-lock behavior have focused regression tests.

The PostGIS/Redis integration suite, native Android/iOS builds, and release web
build require the corresponding local services and SDKs. They are not claimed
as verified by the checks above; run the deployment steps below on the target
machine before releasing.

## Local deployment with Docker Compose

1. From the repository root, create a local environment file. Never commit it:

   ```bash
   cp .env.example .env
   openssl rand -hex 32
   # Put the generated value in SECRET_KEY in .env.
   ```

2. Start the local infrastructure (PostGIS and Redis):

   ```bash
   /opt/homebrew/bin/docker-compose up -d --build
   ```

   If ports 5432, 6379, or 8000 are occupied, use a separate project and host
   ports. This is the configuration used during verification:

   ```bash
   POSTGRES_PORT=55432 REDIS_PORT=56379 \
     /opt/homebrew/bin/docker-compose -p voltez-final up -d --build
   ```

   Compose intentionally starts only PostGIS and Redis. Run the migration and
   application processes from the `backend` directory so they use the same
   environment and the checked-in Alembic history:

   ```bash
   cd backend
   cp .env.example .env                         # edit credentials/ports first
   .venv/bin/alembic upgrade head
   .venv/bin/uvicorn app.main:app --host 0.0.0.0 --port 18000
   ```

   Run the API worker separately when background jobs are enabled. The exact
   worker command depends on the deployment supervisor; do not assume that
   `docker-compose up` starts one automatically.

3. Verify the stack:

   ```bash
   curl -fsS http://localhost:8000/health/live
   curl -fsS http://localhost:8000/health/ready
   backend/.venv/bin/python backend/scripts/smoke_test.py http://localhost:8000
   ```

   With the isolated ports, replace `8000` with `18000`. A healthy readiness
   response has HTTP 200 with `status: "ready"` and `checks.database`,
   `checks.redis`, and `checks.ml` all `true`. A 503 is expected when any
   dependency or either core model is unavailable; inspect the response and
   API logs before treating the deployment as healthy.

4. Inspect service state and logs:

   ```bash
   /opt/homebrew/bin/docker-compose ps
   /opt/homebrew/bin/docker-compose logs --tail=100 db redis
   ```

5. Stop the isolated stack when finished. This does not remove named volumes:

   ```bash
   /opt/homebrew/bin/docker-compose -p voltez-final stop
   ```

The backend uses the checked-in Alembic migrations. Do not use
`Base.metadata.create_all()` in deployment; migration history is the schema
source of truth. Compose only provisions the database and Redis containers;
it does not run migrations or start the API automatically.

## Web testing on the phone (fastest route)

1. Connect the Mac and phone to the same Wi-Fi network.
2. Find the Mac LAN address:

   ```bash
   ipconfig getifaddr en0
   ```

   If that is empty, use `ipconfig getifaddr en1` or the active Wi-Fi interface.
3. Start the API bound to all interfaces. Compose already does this. If running
   Uvicorn directly, use `--host 0.0.0.0`.
4. Build and serve Flutter web using the Mac address. For the verified isolated
   stack, substitute the actual API port (`18000` below):

   ```bash
   flutter build web --release \
     --dart-define=API_BASE_URL=http://<MAC_IP>:18000/api/v1 \
     --dart-define=WS_BASE_URL=ws://<MAC_IP>:18000/api/v1
   python3 -m http.server 3000 --bind 0.0.0.0 --directory build/web
   ```

5. Open `http://<MAC_IP>:3000` on the phone. Allow location access and confirm
   registration, login, charger discovery, route calculation, slot selection,
   booking hold, cancellation, and history persistence.

   For a Flutter web build served to a phone, set `CORS_ORIGINS` in `.env` to
   the exact web origin (for example `http://192.168.1.20:3000`) before starting
   Compose. Native Flutter apps do not send browser `Origin` headers, so CORS
   does not affect Android/iOS requests.

Local HTTP is suitable for a development smoke test. Browser geolocation,
Google Maps, and payment SDKs are more reliable from an HTTPS staging URL.

## Android phone

1. Install Android Studio and its SDK, then accept licenses:

   ```bash
   flutter doctor --android-licenses
   flutter doctor
   ```

2. Enable Developer options and USB debugging on the phone. Connect it by USB,
   authorize the Mac, and confirm it appears in `flutter devices`.
3. For USB testing, use the repository runner. It sets up the required reverse
   tunnel before launching Flutter, so the app's `127.0.0.1` points back to the
   Mac API:

   ```bash
   # From the repository root
   ./frontend/scripts/run_phone.sh
   ```

   The runner verifies an authorized device and configures
   `adb reverse tcp:8000 tcp:8000`. If you prefer Wi-Fi, keep both devices on
   the same network and run `./frontend/scripts/run_phone.sh --lan`; do not use
   `127.0.0.1` in LAN mode because that is the phone itself.

4. To launch manually against the Mac LAN API, use:

   ```bash
   flutter run -d <ANDROID_DEVICE_ID> \
     --dart-define=API_BASE_URL=http://<MAC_IP>:18000/api/v1 \
     --dart-define=WS_BASE_URL=ws://<MAC_IP>:18000/api/v1 \
     --dart-define=RAZORPAY_KEY_ID=rzp_test_your_public_key
   ```

   The cleartext network permission is debug-only. Release builds must use
   HTTPS/WSS and release signing; never ship the debug signing configuration.

## iPhone

1. Install the full Xcode app, select it, finish first launch, and install
   CocoaPods:

   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   sudo xcodebuild -runFirstLaunch
   brew install cocoapods
   pod --version
   ```

2. Copy `ios/Flutter/Secrets.xcconfig.example` to
   `ios/Flutter/Secrets.xcconfig` only if a paid map/geocoding provider is
   enabled. The checked-in map uses OpenStreetMap tiles and native geocoding,
   so no Maps key is required for this flow.
3. Open `ios/Runner.xcworkspace` in Xcode, choose a signing Team, use the
   `com.voltez.app` bundle identifier, enable Developer Mode on the phone, and
   trust the development certificate.
4. Run with the Mac LAN address using the same `flutter run` command shape as
   Android, replacing the device ID. For reliable geolocation and Maps testing,
   prefer an HTTPS tunnel or staging API; iOS may restrict direct local HTTP.

## Production release checklist

- Set `ENVIRONMENT=production`; use a 32+ character random `SECRET_KEY`.
- Set explicit HTTPS `CORS_ORIGINS`; wildcard CORS is rejected in production.
- Configure Razorpay server secret/webhook values and only expose the public key
  ID to the mobile build.
- Use HTTPS for REST and WSS for realtime; terminate TLS at a reverse proxy or
  managed load balancer.
- If a paid map/geocoding provider is enabled, restrict its keys by
  package/bundle ID and API usage; do not commit keys.
- Configure Postgres backups, Redis persistence/alerts, log retention, and a
  deployment health check for `/health/ready`.
- Replace the current FCM/mock notification adapter and simulated session
  telemetry with the real provider/device integration before claiming a
  production charging network.
- Add release Android signing and App Store provisioning; the current machine
  has no Android SDK, complete Xcode install, or CocoaPods, so native release
  artifacts are still an environment task.
