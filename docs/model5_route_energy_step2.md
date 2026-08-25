# Model 5 Step 2 - public route and vehicle data

Status: **implemented locally; pending review and commit**

Training status: **not started**

Hidden-truth status: **not implemented; reserved for Step 3**

Locked-test status: **not accessed**

## 1. What this step adds

Step 2 extends the existing application-shaped synthetic generator with two public tables:

- `vehicle_energy_profiles`: versioned physical priors known before route planning;
- `route_snapshots`: immutable route, traffic, elevation, and weather summaries captured at one
  planning cutoff.

It also links:

- each `trip` to one `direct_route_snapshot_id`;
- each `trip_charger_option` to the snapshot for the origin-to-candidate-charger leg.

This is raw planning-time data. It is not yet a model feature view and does not contain a route
energy target.

## 2. Why these are separate application tables

Vehicle specifications can be corrected or become stale. A versioned profile preserves the values
that were available when a historical prediction was made. Route-provider responses also change
with traffic and provider updates. An immutable snapshot prevents a later API response from
silently rewriting an earlier model decision.

The operational relationship is:

```text
vehicles ──< vehicle_energy_profiles
    │
    └──< trips ──1 direct route snapshot
             │
             └──< trip_charger_options ──1 candidate route snapshot
```

The future training row will join one vehicle profile and one route snapshot at a point-in-time
cutoff. IDs remain lineage fields and will be forbidden as model inputs.

## 3. Vehicle energy profile logic

The generator creates one active profile for every synthetic vehicle. Supported classes are car,
van, two-wheeler, and three-wheeler. The prior ranges differ because treating a commercial van as
a passenger car would understate mass, payload, drag, and likely energy use.

### Public fields

- validity: profile ID, vehicle ID, effective start/end, profile version;
- provenance: `catalogue`, `owner_declared`, or `class_default` plus confidence;
- mechanics: curb mass, default payload, drag area, rolling resistance;
- conversion: drivetrain and regenerative-braking efficiencies;
- battery: usable-capacity and estimated health fractions;
- synthetic lineage: simulation run ID.

### Source behavior

| Source | Default share | Confidence | Behavior |
|---|---:|---:|---|
| Catalogue | 72% | 0.92 | Draws a plausible specification from the vehicle-class range |
| Owner declared | 18% | 0.68 | Adds bounded reporting coarseness to a plausible value |
| Class default | 10% | 0.42 | Uses the archetype's typical value for cold-start fallback |

These are public priors, not the true coefficients used to create a future label. Step 3 must
perturb hidden true coefficients independently so the ML task cannot collapse to one formula.

`battery_health_fraction` is also an estimated planning-time value. The future truth engine may use
a different hidden state within physical bounds.

## 4. Route snapshot logic

One snapshot describes one vehicle, one trip, and one immutable route leg. Two leg types exist:

- `destination`: origin to trip destination;
- `candidate_charger`: origin to a charger considered by the recommendation flow.

Each row records:

- trip/request/vehicle/candidate lineage;
- provider identity, route ID, non-reversible route hash, request time, generation cutoff, expiry;
- synthetic operational coordinates, distance, normal duration, and traffic duration;
- elevation gain/loss and grade summaries when available;
- urban/highway fractions and estimated full-stop count;
- planning-time temperature, precipitation, headwind, air density, and road-surface state;
- separate route, elevation, and weather quality states.

Exact coordinates belong to the application snapshot but will be excluded from the later training
feature view. Training will use aggregate route summaries.

## 5. Parameter logic

### Urban and highway mix

Short routes receive a larger urban fraction. Longer routes gradually receive more highway
distance. Fractions are clipped to physical bounds and always sum to one.

### Normal duration

The generator estimates time by dividing the urban part by a Pune-like urban speed and the highway
part by a higher highway speed. This is better than assigning one unrelated duration because
distance, road type, and duration remain correlated.

### Traffic duration

Traffic delay combines:

- morning and evening peak intensity;
- the urban fraction, because city traffic has more effect than open highway travel;
- the declared synthetic world scenario, including monsoon and local-event disruption;
- small bounded provider variation.

Traffic duration cannot be shorter than normal duration, and the stored ratio must reconcile with
both values.

### Elevation

Gain and loss come from a total vertical-change budget plus a bounded net elevation change. Steep
routes receive additional vertical variation. Maximum grade must be at least consistent with the
mean grade. Missing elevation is represented by null values and the explicit quality state
`missing`; it is never converted to zero elevation.

### Stops

Expected stops increase with distance, urban fraction, and congestion. A Poisson draw introduces
natural count variation while the final count remains non-negative.

### Weather

Temperature follows a bounded Pune-like daily/seasonal cycle. Monsoon scenarios produce more rain,
stronger wind variation, wet road state, and cooler conditions. Air density is derived from
temperature with an altitude-adjusted Pune reference. Weather timestamps always precede the route
cutoff. Missing weather is explicit and contains no fabricated numeric zeroes.

## 6. Route diversity beyond charger searches

Pune charger-search journeys are mostly short urban trips. That is product-realistic but
insufficient for a route-energy model. Step 2 therefore creates one ordinary coverage journey per
vehicle using geographically consistent start/end coordinates in four bands:

| Band | Planned road distance | Purpose |
|---|---:|---|
| Urban short | 2-12 km | Dense city use |
| Urban medium | 12-30 km | Cross-city travel |
| Regional highway | 30-90 km | Sustained-speed drag and reachability |
| Intercity | 90-220 km | High-energy and reserve-SOC cases |

These are real `trips`, not duplicate feature rows. They belong to a vehicle/user, have valid Pune
origins, and use great-circle destination construction so their coordinates agree with distance.
They may exist without a charging request because an ordinary journey is valid application data.

The full Pune profile creates one coverage trip per 6,000 vehicles. The small test profile creates
one per 80 vehicles. This adds diversity without exploding the M4 memory budget.

## 7. Missingness and fallback behavior

The default Pune profile intentionally omits:

- elevation for about 8% of snapshots;
- weather for about 10% of snapshots;
- high-quality route-provider context for a small fallback share.

The small test profile uses 12% elevation/weather missingness so automated tests reliably exercise
fallback paths. The future feature builder must add missingness indicators and class/provider
fallback priors; it must not learn that null means zero energy.

## 8. Validation gates implemented now

Generation fails before files are published if any of these invariants breaks:

- every vehicle lacks exactly one active profile;
- a profile source or physical value is outside the configured contract;
- a trip/user/vehicle ownership relationship is inconsistent;
- any trip or candidate option lacks its required route snapshot;
- a route snapshot references another trip's vehicle, request, or charger;
- request, snapshot, ingestion, or expiry timestamps violate causal order;
- distance/duration is non-positive or traffic duration is shorter than normal;
- urban and highway fractions do not sum to one;
- missing elevation/weather states contain fake numeric values;
- realized energy, arrival SOC, hidden coefficients, driver aggressiveness, or speed traces appear;
- total planned/generated rows exceed the configured safety ceiling.

All tables enter the existing atomic Parquet writer. Their column schemas, SHA-256 hashes, row
counts, code source hash, seed, evaluation role, and overall reproducibility fingerprint are stored
in `manifest.json`.

## 9. Reproducibility and world isolation

Vehicle profiles, coverage trips, and route snapshots use separate named random streams. Changing
route variation cannot silently move a charger or alter Model 1 demand counts. The route-energy
source files participate in the simulation identity, so a code change creates a new run ID instead
of overwriting an older dataset.

The existing experiment overlays still define two training worlds, one validation world, one locked
test world, and one stress world. Step 2 does not generate or inspect the locked test dataset.

## 10. Local review command

Run the small two-day schema rehearsal only:

```bash
uv run voltez-generate \
  --environment test \
  --profile pune_test \
  --output-root /private/tmp/voltez-model5-step2-review
```

Inspect `vehicle_energy_profiles.parquet`, `route_snapshots.parquet`, `trips.parquet`,
`trip_charger_options.parquet`, and `manifest.json`. This command never trains a model.

Do not generate or inspect `test_seed_01` during development.

## 11. Sponsor integration boundary

The provider-shaped contract is ready for a future Google Routes adapter: timestamped route IDs,
traffic-aware duration, route freshness, coordinate retention, and fallback quality are explicit.
Current rows use `synthetic_route_provider` or `deterministic_haversine_fallback`; they do not claim
that Google or another sponsor API was called.

- Google route services can later populate the same route snapshot fields.
- Swytchcode can govern the provider adapter, provenance, and fallback execution.
- CodeMate AI can review unit consistency and causal/leakage gates.
- n8n can later monitor snapshot freshness and approved data-quality workflows.

Sponsor credentials are not required for this synthetic stage.

## 12. Explicit Step 3 boundary

Step 2 does **not** contain:

- segment speed or elevation traces;
- driver aggressiveness or payload truth;
- true physical coefficients;
- SOC-dependent regeneration truth;
- actual battery energy, arrival SOC, or residual labels;
- any trained estimator or model artifact.

Step 3 will implement the hidden 30-second truth simulator and QA-only tables after explicit
approval. Keeping this boundary prevents accidental target leakage and makes review much easier.

## 13. Small-profile rehearsal evidence

The final uncommitted Step 2 rehearsal used the development role, `pune_test`, and the frozen seed.
It produced:

| Check | Result |
|---|---:|
| Vehicle energy profiles | 80 for 80 vehicles |
| Trips | 102 |
| Route snapshots | 133 |
| Ordinary coverage journeys | 80 |
| Snapshot distance range | 0.5-233.133 km |
| Coverage distance bands | 19 short, 33 medium, 17 regional, 11 intercity |
| Coverage urban-fraction range | 0.12-0.98 |
| Traffic-delay-ratio range | 1.00-2.04214 |
| Explicit missing elevation | 24 snapshots |
| Explicit missing weather | 16 snapshots |
| Profile sources | 56 catalogue, 17 owner-declared, 7 class-default |
| Realized/hidden route-energy fields | 0 |

Reproducibility fingerprint:
`229870a7f06c59491e8348090c570ddb9296119ee232715b0e1de9f5495875e3`

The manifest correctly records `code_is_dirty: true` because this was a pre-commit review run. The
automated same-seed test independently generates the dataset twice and requires identical run IDs,
row counts, and content fingerprints.
