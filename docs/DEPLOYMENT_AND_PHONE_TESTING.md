# VoltEZ deployment and phone testing

This guide applies to the `final-frontend` branch. It describes the checked-in
Compose deployment, the local web build, and the native phone prerequisites.

## What is verified in this branch

- ML suite: 133 tests passed.
- Backend integration suite: 6 tests passed against PostGIS and Redis.
- Python compilation and fatal Ruff checks: passed.
- Flutter analyzer: 0 issues; Flutter tests: 4 passed.
- Flutter release web build: passed.
- Isolated Compose stack: PostGIS, Redis, Alembic migration, API, and ARQ worker
  started successfully; `/health/ready` returned database/Redis/ML all `true`.

The native Android and iOS builds cannot be verified on the current Mac until
their SDKs are installed (see the prerequisites section below).

## Local deployment with Docker Compose

1. From the repository root, create a local environment file. Never commit it:

   ```bash
   cp .env.example .env
   openssl rand -hex 32
   # Put the generated value in SECRET_KEY in .env.
   ```

2. Start the complete stack (database, Redis, migration job, API, and worker):

   ```bash
   /opt/homebrew/bin/docker-compose up -d --build
   ```

   If ports 5432, 6379, or 8000 are occupied, use a separate project and host
   ports. This is the configuration used during verification:

   ```bash
   POSTGRES_PORT=55432 REDIS_PORT=56379 API_PORT=18000 \
     /opt/homebrew/bin/docker-compose -p voltez-final up -d --build
   ```

3. Verify the stack:

   ```bash
   curl -fsS http://localhost:8000/health/live
   curl -fsS http://localhost:8000/health/ready
   python scripts/smoke_test.py http://localhost:8000
   ```

   With the isolated ports, replace `8000` with `18000`. Readiness must show
   `database: true`, `redis: true`, and `ml: true`. A 503 is correct when one
   dependency is down; it should not be treated as a healthy deployment.

4. Inspect service state and logs:

   ```bash
   /opt/homebrew/bin/docker-compose ps
   /opt/homebrew/bin/docker-compose logs --tail=100 api worker migrate
   ```

5. Stop the isolated stack when finished. This does not remove named volumes:

   ```bash
   /opt/homebrew/bin/docker-compose -p voltez-final stop
   ```

The Compose database uses the checked-in Alembic migrations. Do not use
`Base.metadata.create_all()` in deployment; migration history is the schema
source of truth.

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
3. Put a restricted Maps key in `~/.gradle/gradle.properties` (or export it):

   ```properties
   GOOGLE_MAPS_API_KEY=your_android_restricted_key
   ```

4. Run the debug app against the Mac LAN API. Do not use `127.0.0.1`; that is
   the phone itself:

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
   `ios/Flutter/Secrets.xcconfig` and put the restricted iOS Maps key there.
   The real file is ignored by Git.
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
- Restrict Maps keys by package/bundle ID and API usage; do not commit keys.
- Configure Postgres backups, Redis persistence/alerts, log retention, and a
  deployment health check for `/health/ready`.
- Replace the current FCM/mock notification adapter and simulated session
  telemetry with the real provider/device integration before claiming a
  production charging network.
- Add release Android signing and App Store provisioning; the current machine
  has no Android SDK, complete Xcode install, or CocoaPods, so native release
  artifacts are still an environment task.
