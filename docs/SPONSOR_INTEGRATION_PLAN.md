# VoltEZ sponsor integration plan

This is the implementation and judging plan for the sponsors named in the
VoltEZ deck. A sponsor counts only when the product has a real, user-visible
or engineering-visible use, a checked-in adapter/workflow, an environment
variable or configuration boundary, timeout/fallback behaviour, and a demo
step that proves it. A logo or an unverified claim is not an integration.

## Runtime architecture

```text
Flutter app
   │ REST/WebSocket
FastAPI ── PostgreSQL/PostGIS + Redis ── trained VoltEZ ML bundles
   │
   ├─ Google Places/Routes (coordinates, ETA and route context)
   ├─ Stripe Checkout (payment truth + signed webhook)
   ├─ FCM (production push delivery; in-app notifications work without it)
   ├─ Tavily (optional, cached public context only)
   └─ Lyzr → Gemini (bounded explanations, never booking/payment truth)
```

The deterministic booking state machine, database, payment verification,
charger status, and ML predictions remain the source of truth. Sponsor APIs can
enrich or explain a result; they must not invent availability, demand labels,
prices, KYC decisions, or payment success.

## Sponsor-by-sponsor use

| Sponsor | Concrete VoltEZ use | Where it belongs | Credential / evidence | Safety boundary |
|---|---|---|---|---|
| **Google for Developers** | India-constrained Places Autocomplete + Details for every map, route and charger-registration search; Routes API for route distance/ETA/geometry; Firebase Cloud Messaging (FCM) for push notifications; optional Google Sign-In. | FastAPI location adapter, route adapter, and notification worker. | `GOOGLE_MAPS_API_KEY` on the server, restricted to Places/Routes APIs; Firebase service-account secret for FCM; Android/iOS package restrictions. Show a selected address, map recenter, and ETA in the demo. | API results are coordinate-backed and cached briefly. OSM/native geocoder remains a fallback. Never treat a place label as a charger or payment fact. |
| **Stripe** | Hosted Checkout for UPI/card payment, server-side session verification, and signed `checkout.session.completed` webhook that confirms a booking. Cash remains an explicit pay-at-charger option. | `backend/app/api/v1/payments.py` and the Flutter payment screen. | `STRIPE_SECRET_KEY=sk_test_...`, `STRIPE_WEBHOOK_SECRET=whsec_...`, HTTPS `STRIPE_SUCCESS_URL` and `STRIPE_CANCEL_URL`. Use test mode for the demo; secrets stay in the deployment secret store. | The backend, not the phone, confirms payment. Webhook signatures and booking ownership are verified; the tariff is locked at hold time. |
| **Render** | Deploy the FastAPI service, PostgreSQL/PostGIS, Redis and a worker with health checks, secret environment variables and separate staging/production services. | `Dockerfile`, Compose parity, and Render service configuration owned by deployment. | Render account/project, database and Redis connection URLs, TLS domain. Prove `/health/live` and `/health/ready` from the deployed URL. | Do not run migrations from multiple instances; run `alembic upgrade head` as a one-time release command and keep worker/API process roles separate. |
| **Tavily** | Optional public-context enrichment: cached festivals, road disruptions, weather advisories or business-event context that can explain demand spikes and off-peak windows. | A backend context-event worker, normally scheduled by n8n. | `TAVILY_API_KEY` in the worker secret store; record source URL, retrieval time and query in `analytics.context_events`. | Tavily never supplies charger availability, demand labels, KYC decisions or final prices. Use an allowlist, timeout, rate limit and stale-cache fallback. |
| **n8n** | Orchestrate scheduled context refreshes, feature-snapshot jobs, model-evaluation reports, Stripe/FCM notifications and retry/dead-letter workflows. | n8n workflows call authenticated FastAPI admin/worker endpoints. | n8n instance URL plus an HMAC/shared secret for webhooks. Export workflow JSON and show one successful run. | Every workflow is idempotent, has a timeout/retry policy, and cannot bypass booking/payment authorization. |
| **Lyzr** | A bounded “VoltEZ Copilot” that can explain a forecast, summarize reviews, explain a dynamic-price reason, or answer charger-filter questions using read-only VoltEZ tools. | Backend-only agent gateway; Flutter displays its structured response. | `LYZR_API_KEY` and the selected model/config in secret storage. Include one redacted request/response fixture and an offline template fallback. | No direct booking, cancellation, KYC or payment tool. PII is redacted, tool inputs are allowlisted, and the answer is clearly labelled as an explanation. |
| **Google Gemini** | Structured natural-language explanations and review summaries for the same read-only Copilot flows; optionally parse a driver's free-text charging goal into validated filters. | Through Lyzr orchestration or a small FastAPI Gemini adapter, never directly from the phone. | `GEMINI_API_KEY` (or Vertex service account), model/version and safety settings. Keep prompts/versioned outputs for the demo. | Gemini is not the numerical ML model and cannot override deterministic scores, prices, availability, KYC or payment status. |
| **Swytchcode** | Use the sponsor coding environment to implement or review one production slice (for example the location/payment adapter) and attach the generated review/engineering artifact to the project submission. | Development workflow and repository history, not runtime traffic. | Link or export the actual Swytchcode session/artifact; do not claim an SDK integration without one. | Generated code still passes Ruff, Flutter analyze, tests and manual review. No secrets are pasted into the coding tool. |
| **CodeMate AI** | CI/code-review pass for API contract drift, null-safety, overflow-prone widgets, migration consistency and test generation. | Pull-request/CI workflow on `final-frontend`. | Commit the CodeMate report or link and show one caught issue plus the resulting test. | It is an engineering assistant, not a production decision-maker; all fixes are reviewed by the team. |
| **StartupEd / startuped** | Owner onboarding and EV-host education: safety checklist, charger-host playbook, pricing/availability guidance and links in the business onboarding/help area. | Curated content module and optional referral link; no fabricated API. | Use the programme's approved content/URL and record the attribution in the README/demo. | Do not present generic content as legal, electrical or KYC approval. |
| **MLH (Major League Hacking)** | Open-source project hygiene: public repository, clear README, architecture/data cards, reproducible demo, contributor attribution and a judge-ready submission page. | Repository/docs and hackathon submission. | Public repo URL, license, demo video/script, model cards and sponsor evidence links. | MLH is an ecosystem/competition sponsor, not a runtime dependency. Verify the current event rules before submission. |

## What is already implemented in this branch

- Google-style location plumbing is implemented behind
  `GET /api/v1/locations/search`. With `GOOGLE_MAPS_API_KEY` set, the backend
  uses Places Autocomplete + Details; without it, it falls back to an
  India-constrained Nominatim adapter. Flutter map search, route fields and
  charger registration all consume coordinate-backed suggestions.
- Stripe hosted Checkout, signed webhook handling and server-side verification
  are implemented. Stripe becomes the active provider when a real secret key is
  configured; Razorpay is retained only as a development/legacy fallback.
- In-app notifications are persisted and readable. FCM delivery, KYC provider
  verification, OCPP/real charger telemetry and Render deployment still need
  external credentials or infrastructure before they can be called production
  integrations.
- VoltEZ Model 1 (demand) and Model 2 (availability) are loaded from hash-
  verified bundles and are used by recommendation/analytics inference. Their
  outputs are audited in the database; synthetic Pune data is a demo baseline,
  not a real-world accuracy guarantee.

## Minimum sponsor demo sequence

1. Search a Pune landmark in the map and select a Google-backed suggestion; the
   map recenters and live chargers are queried around its coordinates.
2. Register a charger by selecting a Google-backed address, connector and
   first port; refresh the business dashboard and show the active count.
3. Open route planning, select coordinate-backed origin/destination results,
   and show a recommendation whose price and wait explanation come from the
   backend's ML/deterministic pipeline.
4. Hold a slot, complete Stripe test Checkout, return to the app, and show the
   server-confirmed booking plus the signed webhook path in the logs.
5. Trigger one n8n/FCM or Copilot explanation workflow and show its fallback
   behaviour when the optional provider is unavailable.

Before submission, replace every “planned/optional” item above with evidence or
label it honestly as not enabled. Sponsor prize criteria and accepted product
usage can change; check the event's current rules on submission day.
