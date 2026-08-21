# VoltEZ Synthetic Generator — Logic and Builder Guide

This document explains Step 5 in plain language and then connects each idea to the relevant code.
The generator creates training **raw material** for Demand Forecasting and Charger Availability
Prediction. It does not train either model.

## 1. The mental model

The simulator behaves like a small artificial VoltEZ marketplace:

1. Create Pune zones with different hidden demand tendencies.
2. Place users, businesses, schedules, amenities, offers, chargers, normalized ports, parking
   spaces, tariffs, and vehicles into that city.
3. Move through 15-minute time buckets and decide how many genuine charging requests occur.
4. Find compatible ports in the requested zone and its two geographically nearest Pune zones.
5. Apply application rules before showing candidates: connector compatibility, access hours, known
   faults, and confirmed booking conflicts.
6. Record trips, trip charger options, and every recommendation impression, not only the
   selected result.
7. Simulate selection, booking, cancellation, no-show, arrival, failure, and completed charging.
8. Produce noisy owner/driver reports separately from trustworthy check-in/session evidence.
9. Aggregate the raw events into complete demand buckets.
10. Reconstruct availability as available, unavailable, or unknown according to evidence quality.
11. Validate the result and write versioned Parquet files plus a manifest.

The order is causal. A future session cannot influence a recommendation that happened earlier.

## 2. Code map

| File | Responsibility | Why it is separate |
| --- | --- | --- |
| `config.py` | Typed settings and parameter bounds | Bad settings fail before expensive work begins |
| `synthetic/randomness.py` | Named random streams, stable IDs, count-distribution math | Reproducibility rules stay independent of business logic |
| `synthetic/entities.py` | Schema v1.1 identity, geography, hosts, schedules, supply, tariffs, and vehicles | Static application state is created before mutable events |
| `synthetic/events.py` | Demand, requests, recommendations, bookings, sessions, reports, labels | Preserves causal event order in one visible pipeline |
| `synthetic/validation.py` | Memory preflight and post-generation invariants | A bad dataset is rejected before training can read it |
| `synthetic/io.py` | Parquet files, schema hashes, content hashes | Storage mechanics cannot silently change model logic |
| `synthetic/generator.py` | Top-level orchestration and manifest | Provides one approved entry point |
| `synthetic/cli.py` | Local command-line interface | Gives both teammates the same repeatable command |

## 3. Reproducible randomness

### Named streams

The project does not use one global random generator. It creates deterministic streams with names
such as `static-supply`, `demand-counts`, `sessions`, and `user-status-reports`.

The project uses two independent seed families:

- `project.structural_seed + SHA-256(structural stream name)` freezes geography, businesses,
  chargers, ports, tariffs, and inherent port-health profiles;
- `project.seed + SHA-256(dynamic stream name)` varies drivers, demand, context, outages,
  requests, bookings, sessions, and reports.

Therefore:

- the same seed and stream name reproduce the same values;
- supply and demand use independent random sequences;
- adding a new driver-status draw does not unexpectedly change every charger ID.

Changing only `project.seed` creates another history inside the same city. Changing
`project.structural_seed` deliberately creates a different artificial charging network and is
reserved for out-of-distribution robustness.

### Stable identifiers

Physical synthetic IDs use UUID5 over:

`structural namespace + entity type + natural synthetic key`

Drivers and event IDs instead use the dynamic run ID. This lets the same charger be followed
across ordinary train, validation, and test worlds without pretending the same drivers or
bookings occurred in all of them.

They look like normal UUIDs but contain no email, phone, name, or other personal information.

### Run identity

The run ID includes hashes of:

- structural seed, dynamic seed, and city;
- time buckets and model horizons;
- every synthetic profile parameter;
- feature and label versions;
- generator source files.

Changing code or configuration therefore creates a new run identity instead of silently
overwriting an incompatible dataset.

## 4. Static artificial city

### Zones

The first 24 zone names and centroids use recognizable Pune areas. These are coarse synthetic
centers, not addresses or live user locations. Each zone receives hidden QA-only parameters such
as a demand multiplier and price sensitivity.

The controlled `zone_type` is public because maps, analytics, and cold-start behavior may safely
know whether an area is residential, office, retail, transit, or mixed. `qa_latent_zones` keeps
only the hidden numerical multipliers that directly generate demand; those remain forbidden as
model features.

### Businesses and access hours

Businesses are distributed across zones and assigned categories such as cafe, mall, office,
hotel, fuel station, or residential. Category affects access hours. For example, offices have
shorter weekend access while malls remain open later.

The availability model may later use category and known opening hours because the real app would
know them at prediction time.

### Chargers, ports, and parking

A charger is a physical unit. A port is an independently bookable connector. A parking space is
the physical resource promised to the driver. Ports and parking spaces independently reference
their charger, and a booking stores both selected resource IDs.

Prices come from a time-bounded port tariff and are copied into an immutable booking quote. A
later tariff edit therefore cannot rewrite what the driver accepted.

Connector and power choices vary between AC and DC. A booking is impossible unless the vehicle's
connector matches the port's connector.

### Drivers and vehicles

Synthetic users and vehicles follow the v1.1 ownership relationship. The simulator keeps coarse
home zone only in `qa_latent_driver_profiles` to create origins; it is not a public model feature.
Vehicles store battery, range, efficiency, maximum AC/DC power, class, and normalized connector
compatibility.

## 5. Demand generation logic

One count is generated for every:

`zone × local date × 15-minute bucket`

The expected count is approximately:

`mean = daily average × time profile × zone/spillover factor × weekend factor × scenario factor`

### Time profile

The profile has morning, midday, and evening peaks plus a low base rate. It is normalized so its
96 fifteen-minute weights sum to one day.

### Spatial spillover

The zone multiplier blends the zone's own hidden tendency with the mean of its two synthetic
neighbors:

`blended = (1 - spillover weight) × own + spillover weight × neighbor mean`

Increasing `spatial_spillover_weight` makes adjacent zones behave more similarly. At zero, each
zone behaves independently. At one, neighbor behavior dominates.

### Why Negative Binomial counts

Real demand is burstier than a simple Poisson process. VoltEZ uses this parameterization:

`n = dispersion`

`p = dispersion / (dispersion + mean)`

Its variance is:

`variance = mean + mean² / dispersion`

Increasing dispersion reduces extra burstiness and approaches Poisson-like variance. Decreasing
it produces more zeros and occasional spikes. Automated tests lock this direction so the team does
not misinterpret the parameter.

### Why requests are the label

Each count becomes a real `charging_request`, even when no charger is found. The demand label is
therefore the number of legitimate requests, not the number of bookings. A booking measures served
demand; `no_candidate` measures unmet demand.

## 6. Recommendation and booking logic

### Hard filters

Before scoring, a port must pass:

- connector compatibility;
- business opening hours at ETA;
- no known fresh fault at request time;
- no booking conflict known at request time.

These are application truths, not predictions. Model 2 must never override them.

### Candidate area

Candidates come from the destination zone and its two nearest zone centroids using haversine
distance. Google Maps can later replace this adapter with actual route time without changing
label-generation rules.

### Initial recommendation score

This simulator score is not one of the two trained models:

`score = 0.45 power + 0.25 price + 0.20 proximity + 0.10 random preference`

It exists to create realistic selection bias. Drivers are more likely to pick a high-scoring port,
but the softmax choice means they do not always choose rank one.

### Duration estimate

Required energy comes from battery capacity and the gap between current and target SOC. Charging
power is the smaller of vehicle and port capacity. The estimate adds overhead, rounds upward to a
15-minute boundary, and is limited to 30–180 minutes.

### Conflict protection

Bookings use half-open intervals `[start, end)`. A booking ending at 15:00 does not conflict with
one starting at 15:00. Active bookings and their parking spaces are checked for overlap. A
cancellation frees capacity only after its cancellation is known.

## 7. Sessions, outages, and reports

### Hidden operational truth

Outage intervals and actual sessions determine whether a port was physically usable. A session can
run beyond its reserved duration, causing a later arrival to fail even though no booking conflict
was visible when the recommendation was made.

### Evidence sources

- QR-backed driver check-in/check-out events are trustworthy session evidence.
- Owner declarations may be delayed, stale, or wrong.
- Voluntary GPS-backed driver reports use a separate configurable error probability.
- A driver no-show says nothing reliable about whether the charger worked.

This distinction lets Model 2 learn how report source and freshness affect confidence.

## 8. Availability label logic

The simulator calculates hidden QA truth for every shown candidate:

`available = open AND no outage AND no conflicting session AND no blocking booking`

That hidden truth goes only to `qa_latent_availability`.

The public training label follows evidence:

- `available`: the selected driver successfully began charging at a target-consistent time, or
  strong independent evidence supports
  availability;
- `unavailable`: a verified check-in failure shows the charger could not be used;
- `unknown`: the driver cancelled, did not arrive, arrived after the target state changed, or the
  unselected candidate lacks strong
  evidence.

This intentionally creates cases where QA truth is available but the public label remains unknown.
That is correct: the real application would not know the hidden truth.

## 9. Demand buckets

`demand_buckets` contains every zone/time combination, including zeros. Missing rows are never
silently interpreted as zero. Each bucket includes search-subset count, total requests, served and
unserved requests, bookings, sessions, occupancy rate, listed ports, and available ports.

`search_count` is not added to `request_count`: one intent can create both records, so addition
would double-count demand. Model 1's primary target remains the deduplicated request count.

This table is the raw chronological input for the next feature-engineering step. Future targets and
lags have not yet been created, preventing accidental leakage at this stage.

## 10. Safety and validation

### Before generation

A conservative row estimate considers time-grid size, maximum ports, availability windows,
expected request volume with headroom, recommendations, labels, and status events. The full Pune
profile currently estimates about 2.87 million rows against a 5-million-row ceiling.

### After generation

Validation checks:

- foreign keys;
- connector compatibility;
- booking and parking overlap;
- booking state transitions;
- positive time intervals;
- session timestamps, energy, and SOC bounds;
- meter-energy and non-negative price reconciliation;
- route request/trip linkage and non-negative option estimates;
- user/vehicle ownership and charger/parking alignment;
- status observation-versus-ingestion timing and confidence bounds;
- availability cutoff timing;
- complete demand grid;
- one simulation lineage ID;
- no latent columns in public tables;
- exact row ceiling.

### Atomic output

Files are first written under `.run-id.incomplete`. The final directory appears only after all
tables and the manifest are valid. Replacement is explicit and keeps a recoverable `.previous`
directory. Partial output is never presented as a complete training dataset.

## 11. Manifest and data files

Every table is compressed Parquet. The manifest records row counts, column order, schema hashes,
file hashes, seed, city, date range, generator-source hash, Git commit, dirty-state flag, feature
version, label version, experiment name, and declared evaluation role. The seed and role both
participate in the simulation identity so a locked test run cannot be silently relabeled.

Public operational/analytics tables include:

- users, zones, businesses, schedules, amenities, offers, chargers, normalized ports, parking,
  availability windows, and tariffs;
- vehicles and normalized connector compatibility;
- requests, trips, trip charger options, impressions, bookings, booking events, sessions, and
  status events;
- context events, demand buckets, and availability observations.

Files prefixed `qa_latent_` are simulator testing truth. Training code must reject them as features.

## 12. Parameters and their effects

| Parameter | Increasing it does what? | Main risk |
| --- | --- | --- |
| `days` | Adds more chronological history | More memory, disk, and runtime |
| `zone_count` | Adds spatial detail | Sparser data per zone |
| `business_count` | Adds host diversity | More supply entities |
| `charger_count` | Adds charging supply | Can make `no_candidate` unrealistically rare |
| `driver_count` | Adds vehicle/driver diversity | Larger static tables |
| `average_requests_per_zone_per_day` | Raises total demand | More conflicts and event rows |
| `negative_binomial_dispersion` | Reduces burstiness | Very high values may look too smooth |
| `spatial_spillover_weight` | Correlates neighboring zones | Too high erases local differences |
| `base_operational_probability` | Reduces outage frequency | Too high produces too few false labels |
| owner/user report error | Adds incorrect reports | Too high makes reports unrealistic |
| `median_status_ttl_minutes` | Keeps reports usable longer | Stale evidence may appear current |
| min/max ports per charger | Adds capacity per charger | Larger availability-window tables |
| `recommendations_per_request` | Records more alternatives | Larger impression/observation tables |
| `selection_probability` | Converts more searches into bookings | Can hide abandonment behavior |
| cancellation/no-show probability | Reduces successful attendance | Fewer trustworthy availability labels |
| `maximum_generated_rows` | Allows larger simulations | Setting above safe RAM defeats protection |

The `pune_test` profile deliberately uses a 70% operational probability to force outage tests. The
real `pune_v1` profile remains at 96%; test stress values must never be presented as Pune reality.

## 13. Apple M4 execution

Generation is tabular CPU work. NumPy, Pandas, and PyArrow run natively on arm64. MPS does not help
this pipeline, so no fake GPU flag is used. The full run should be performed only after reviewing
the small profile and while enough memory/disk is available.

## 14. Commands

Small review run:

```bash
uv run voltez-generate --environment test --profile pune_test
```

Full 90-day Pune generation, only after explicit approval:

```bash
uv run voltez-generate --environment development --profile pune_v1
```

Verification:

```bash
uv run pytest
uv run ruff check .
uv run mypy
```

## 15. Sponsor boundaries

Sponsor credentials are not needed for synthetic truth. Later integrations should be adapters:

- Google for Developers: real route time, distance, and Places enrichment;
- Tavily: provenance-aware discovery of public event/context sources;
- Swytchcode: governed external API execution and audit;
- CodeMate AI: independent code/leakage review;
- Render: hosted generator jobs, inference API, PostgreSQL, and workers;
- n8n: approved refresh, monitoring, and retraining workflows;
- Gemini/Lyzr: explanations and agents around validated numerical outputs.

No sponsor LLM or search API should manufacture demand or availability labels.

## 16. Knowledge check

1. Why does changing the random draw in `user-status-reports` not change charger IDs?
2. What happens to demand variance when Negative Binomial dispersion increases?
3. Why can hidden availability be true while the public label is unknown?
4. Name four hard filters that run before availability prediction.
5. Why are recommendation impressions stored for unselected ports?
6. Which test-profile parameter is intentionally unrealistic, and why?
7. Why is CPU execution correct for this generator on Apple M4?
