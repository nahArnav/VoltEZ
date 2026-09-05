# VoltEZ manual Render production cutover

This runbook is intentionally manual. Committing it does not change the live Render service.

## What was measured on 5 September 2026

| Component | Observed live state | Consequence |
|---|---|---|
| Web service | Render Singapore, `1c-2g`, branch `main` | CPU/RAM are not the current bottleneck |
| Traffic | 202 requests in 12 hours | Current load is very small |
| PostgreSQL | Neon US East 2, PostgreSQL 18.6, 17 MB | About 1.8 s to connect and 208 ms per warm `SELECT 1` from Render |
| Redis | Upstash, 5 ARQ keys, no active hold keys | About 65 ms per warm ping from Render |
| Worker | No Render background worker | Delayed booking-expiry jobs are not being consumed |
| App mode | `development` | Production validation is disabled |
| Signing secret | `SECRET_KEY` absent on Render | The deployed app falls back to the known development secret |
| Google Places | Old Place Details fan-out returned 429 | `final-frontend` now uses one verified Text Search request |
| ML bundles | Demand and availability only | Waiting-time and reliability use labelled synthetic fallback logic |

The right first move is regional colocation, not a larger web server. Render recommends using an
internal database URL from a database in the same region because it minimizes latency and uses the
private network: <https://render.com/docs/postgresql-creating-connecting>.

## Expected extra monthly cost

These are the prices shown in the Render dashboard on 5 September 2026 and can change.

| Resource | Initial size | Monthly price |
|---|---:|---:|
| Render Postgres | 0.1 CPU, 256 MB RAM, 1 GB storage | $6.30 |
| Render Key Value | 256 MB, persistent | $10.00 |
| Render background worker | 0.5 CPU, 512 MB RAM | $7.00 |
| **Additional total** | | **$23.30/month** |

The 17 MB database and tiny request volume do not justify a larger database today. Increase the
database plan only after metrics show CPU, memory, or connection pressure.

## 1. Prepare the code and a rollback point

1. Confirm the deployment commit is on `final-frontend` and that `main` remains untouched.
2. Keep the existing Neon database and Upstash Redis instance running until the new stack has been
   stable for at least 24 hours.
3. Schedule a short maintenance window. The new production `SECRET_KEY` invalidates existing login
   tokens and changes deterministic booking/cash codes, so users will need to sign in again.
4. Never put database URLs, Redis URLs, or API keys in Git, the APK, shell screenshots, or this file.

## 2. Create Render Postgres

In Render, choose **New → Postgres** and use:

- Name: `voltez-postgres`
- Project/environment: `VoltEZ / Production`
- Region: `Singapore (Southeast Asia)`
- PostgreSQL: `18`
- Compute: `0.1c-256mb` ($6/month)
- Storage: `1 GB` ($0.30/month)
- Storage autoscaling: off initially; alert and increase before reaching the limit

Render supports both `postgis` and `btree_gist`, which VoltEZ requires:
<https://render.com/docs/postgresql-extensions>.

Use the **external** URLs only from the Mac during migration. After migration, the web service and
worker must use the Render database's **internal** URL.

With PostgreSQL 18 client tools installed, export Neon and restore into the empty Render database:

```bash
export VOLTEZ_OLD_DB_URL='<NEON_EXTERNAL_DATABASE_URL>'
export VOLTEZ_NEW_DB_URL='<RENDER_EXTERNAL_DATABASE_URL>'

pg_dump \
  --dbname="$VOLTEZ_OLD_DB_URL" \
  --format=custom \
  --no-owner \
  --no-acl \
  --file=voltez-neon.backup

pg_restore \
  --dbname="$VOLTEZ_NEW_DB_URL" \
  --no-owner \
  --no-acl \
  --exit-on-error \
  voltez-neon.backup
```

Restore only into an empty destination. Render's backup and restore guidance is here:
<https://render.com/docs/postgresql-backups>.

Verify the destination before switching the app:

```bash
psql "$VOLTEZ_NEW_DB_URL" -c \
  "SELECT extname FROM pg_extension WHERE extname IN ('postgis', 'btree_gist') ORDER BY extname;"

psql "$VOLTEZ_NEW_DB_URL" -c \
  "SELECT pg_size_pretty(pg_database_size(current_database()));"
```

Unset the URLs when finished so they do not leak into later shell commands:

```bash
unset VOLTEZ_OLD_DB_URL VOLTEZ_NEW_DB_URL
```

## 3. Create Render Key Value

In Render, choose **New → Key Value** and use:

- Name: `voltez-key-value`
- Project/environment: `VoltEZ / Production`
- Region: `Singapore (Southeast Asia)`
- Plan: persistent 256 MB ($10/month)
- Maxmemory policy: `noeviction`
- Persistence: `Journal + Snapshot`
- External access: disabled after setup unless it is genuinely required

`noeviction` is Render's recommendation for job queues so queued jobs are not silently discarded:
<https://render.com/docs/key-value>.

Do not migrate the current Upstash keys. They are delayed ARQ job metadata, not authoritative app
data. The new worker reconciles overdue `pending`/`held` bookings from PostgreSQL at startup before
processing new jobs.

## 4. Configure the existing web service

Change the service to `final-frontend` only when the maintenance window begins.

Use these commands and settings:

```text
Branch:             final-frontend
Build Command:      bash build.sh
Pre-Deploy Command: cd backend && alembic upgrade head
Start Command:      cd backend && uvicorn app.main:app --host 0.0.0.0 --port $PORT --workers 1
Health Check Path:  /health/live
```

Set these environment variables in addition to the existing provider keys:

```text
ENVIRONMENT=production
SECRET_KEY=<Render-generated random value of at least 32 characters>
DATABASE_URL=<Render Postgres INTERNAL URL>
REDIS_URL=<Render Key Value INTERNAL URL>
DB_POOL_SIZE=5
DB_MAX_OVERFLOW=5
DB_POOL_RECYCLE_SECONDS=240
DB_POOL_TIMEOUT_SECONDS=10
DB_CONNECT_TIMEOUT_SECONDS=10
WORKER_HEALTH_CHECK_KEY=voltez:worker:health
```

Generate `SECRET_KEY` once in Render and store a backup in a password manager. Rotating it logs out
every user and changes outstanding deterministic OTPs.

Keep the existing values for `GEMINI_API_KEY`, `GOOGLE_MAPS_API_KEY`, and `TAVILY_API_KEY`. The live
audit verified all three. `LYZR_API_KEY`, `STARTUPED_API_KEY`, and `SWYTCHCODE_API_KEY` are present
but the current backend does not implement those provider calls.

## 5. Create the required background worker

Render background workers continuously consume queues without accepting public traffic:
<https://render.com/docs/background-workers>.

Create a **Background Worker** with:

```text
Name:          voltez-booking-worker
Project:       VoltEZ / Production
Language:      Python 3
Branch:        final-frontend
Region:        Singapore
Build Command: bash build.sh
Start Command: cd backend && arq app.worker.WorkerSettings
Plan:          0.5c-512mb ($7/month)
```

Give the worker the same `DATABASE_URL`, `REDIS_URL`, `ENVIRONMENT`, `SECRET_KEY`, Python version,
database-pool values, and `WORKER_HEALTH_CHECK_KEY` as the web service. Provider API keys are not
needed by this worker.

## 6. Deploy and verify

Deploy the worker and web service, then check:

```bash
curl -fsS https://voltez-sb0w.onrender.com/health/live
curl -fsS https://voltez-sb0w.onrender.com/health/ready
curl -fsS https://voltez-sb0w.onrender.com/

curl -fsSG https://voltez-sb0w.onrender.com/api/v1/locations/search \
  --data-urlencode 'q=Pune Railway Station' \
  --data-urlencode 'limit=3'
```

The expected production state is:

- `/health/live` returns HTTP 200;
- `/health/ready` returns HTTP 200 with database, Redis, worker, and core ML checks true;
- `/` reports `environment: production`;
- location search returns coordinate-backed results without Place Details fan-out;
- a new unpaid booking becomes `expired` after its ten-minute hold;
- authenticated profile, charger search, booking, and route-planning requests no longer show
  `connection is closed` in Render logs.

Demand and availability should report loaded model IDs. Waiting-time and reliability will still
report `synthetic-*-fallback-v1` until actual promoted bundles are added under
`backend/models/waiting_time/` and `backend/models/reliability/`. Do not label those fallbacks as
trained production models.

## 7. Roll back if verification fails

1. Put the web service back in maintenance mode.
2. Restore `DATABASE_URL` and `REDIS_URL` to the untouched Neon and Upstash values.
3. Restore the previously deployed branch/commit.
4. Redeploy and confirm `/health/live` and authenticated API calls.
5. Keep the failed Render resources until the cause is understood; do not delete the only copy of
   migrated data.
