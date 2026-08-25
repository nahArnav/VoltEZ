# VoltEZ Demo Script (4-6 Minutes)

## Opening (20 seconds)
**Problem**: EV chargers exist but discovery, trust and utilization are fragmented. Private/commercial chargers in malls, offices and apartments are underutilized.

---

## 1. Owner Side (~90 seconds)

1. Open business dashboard.
2. Show **low-utilization hours** highlighted on the analytics page.
3. Show AI recommendation: **"Open 2-5 PM"**.
4. Expand **"Why?"** panel:
   - Forecast demand for that time slot
   - Nearby supply analysis
   - Confidence score
5. **Accept** the recommendation → availability window created automatically.

---

## 2. Driver Side (~90 seconds)

1. Select vehicle (shows connector type, battery, range).
2. Set current SOC and destination.
3. System **silently rejects** incompatible/unreachable options.
4. Show **top 3 ranked recommendations**.
5. Open **"Why this charger?"** for the top result:
   - Detour: X minutes
   - Predicted wait: X minutes
   - Charge time: X minutes
   - Estimated cost: ₹X
   - Reliability: X%

---

## 3. Booking Flow (~60 seconds)

1. **Reserve** the top charger.
2. Point out the **temporary hold countdown** (5 minutes).
3. Explain: Redis lock prevents double-booking + DB overlap constraint as source of truth.
4. Complete **sandbox payment**.
5. Show booking confirmed → check-in.

---

## 4. Session & Analytics (~30 seconds)

1. Complete check-in/session quickly (or use a prepared near-complete session).
2. Return to **business dashboard**: utilization, revenue, and session metrics update in real-time.

---

## 5. Sponsor Enhancement (~30 seconds)

Show **one** sponsor-powered feature:
- Gemini/Lyzr explanation of a recommendation
- n8n event workflow triggered by completed booking
- Tavily ecosystem brief with cited sources

---

## 6. Close (~30 seconds)

**Architecture and measurable proof:**
- Deployed system (live URL, health endpoint)
- Concurrency test result (20 requests → 1 winner)
- ML model beats baseline (show metrics)
- Graceful fallback when external API is down

---

## Backup Plan

Keep screenshots and a recorded video walkthrough in case of network/deployment issues during live demo.
