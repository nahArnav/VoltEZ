# Model 5 route-energy prediction - Step 1 design

Status: **problem, physics baseline, data contract, synthetic requirements, and evaluation plan**

Training status: **not started**

Locked-test status: **not accessed**

Machine-readable design: `configs/model_specs/route_energy_v1.yaml`

Executable baseline: `src/voltez_ml/route_energy/physics.py`

## 1. What Model 5 answers

For one vehicle and one immutable route snapshot, Model 5 should estimate:

1. expected battery energy consumption in kWh;
2. a conservative P90 energy requirement;
3. expected and conservative arrival SOC;
4. whether the destination or candidate charger is `reachable`, `borderline`, or `unreachable`;
5. a safety margin and prediction-quality state.

The row grain is:

`one vehicle x one route snapshot x one planned route leg`

A route leg may end at the trip destination or at a candidate charger. Using the same contract for
both avoids maintaining separate energy models for ordinary navigation and charger reachability.

The model predicts energy for the route supplied by the route provider. It does not choose the
route, filter connector compatibility, or reserve a charger.

## 2. Why this must be a hybrid physics + ML system

Basic vehicle energy relationships are known before VoltEZ collects data:

- greater distance increases rolling and aerodynamic energy;
- greater vehicle mass increases rolling, climbing, and stop-start energy;
- aerodynamic energy increases approximately with air-speed squared;
- climbing consumes gravitational potential energy;
- downhill travel can recover only a bounded fraction through regenerative braking;
- longer journeys consume more accessory/HVAC energy;
- repeated acceleration and braking loses energy even when regeneration is available.

Training a tree model to rediscover all of this from synthetic rows would be wasteful and fragile.
The recommended architecture is therefore:

`final energy = deterministic physics estimate + learned residual correction`

The physics estimate is always available as a fallback. The future ML residual corrects systematic
errors caused by traffic patterns, temperature, route aggregation, battery condition, uncertain
vehicle specifications, and driving behavior.

## 3. Executable physics baseline

The baseline is implemented now because it defines the target residual and lets every formula be
unit-tested before synthetic labels are generated. It is not model training.

### 3.1 Rolling resistance

`rolling force = Crr x mass x gravity`

`rolling energy = rolling force x distance`

`Crr` is the rolling-resistance coefficient. Wet roads, tyre pressure, and tyre construction can
change it. The public physics baseline receives a nominal value; the hidden synthetic truth engine
may use a perturbed true value.

### 3.2 Aerodynamic drag

`drag force = 0.5 x air density x drag area x effective air speed squared`

`drag energy = drag force x distance`

`drag area` is drag coefficient multiplied by frontal area. Effective air speed is vehicle speed
plus headwind. A tailwind may reduce it but never below zero in this simplified baseline.

Because speed is squared, a fast highway journey can consume much more energy per kilometre than a
moderate-speed urban journey even when distance is identical.

### 3.3 Climbing and downhill regeneration

`climb energy = mass x gravity x elevation gain`

`descent regeneration = mass x gravity x elevation loss x regen efficiency`

The baseline divides positive wheel energy by drivetrain efficiency to obtain battery energy.
Regeneration is a credit, but it is capped by an efficiency below one and total consumption is
never allowed to become negative.

### 3.4 Stop-start energy

Every full acceleration requires approximate kinetic energy:

`kinetic energy = 0.5 x mass x mean speed squared`

Acceleration draws energy through drivetrain losses. Deceleration recovers only part of it. The
net stop-start cost is therefore positive even with regenerative braking.

### 3.5 Auxiliary load

`auxiliary energy = auxiliary power x route duration`

This represents HVAC, battery thermal management, electronics, lights, and other accessories. The
first baseline accepts an aggregate kW value. The future feature builder will estimate that value
from temperature, precipitation, vehicle class, and route duration.

### 3.6 Final baseline

`baseline = rolling + aerodynamic + climb + stop-start + auxiliary - descent regeneration`

All quantities are converted to kWh and the result is clipped at zero. The code returns every
component separately so mistakes are auditable and the future residual model can use the component
estimates as features.

## 4. Parameter effects

| Parameter | If it increases | Important caution |
|---|---|---|
| `distance_km` | Rolling, drag, and usually auxiliary energy increase | Duration must remain consistent with a plausible speed |
| `total_mass_kg` | Rolling, climbing, and stop-start energy increase | Include passengers/payload, not only curb mass |
| `drag_area_m2` | Highway energy increases | Vehicle-class averages are uncertain priors |
| `rolling_resistance_coefficient` | Energy per kilometre increases | Wet road and tyre condition change the real coefficient |
| `headwind_mps` | Aerodynamic energy rises nonlinearly | Route-level wind is uncertain and time-sensitive |
| `elevation_gain_m` | Climbing energy increases | Provider elevation estimates may be noisy |
| `regenerative_braking_efficiency` | Downhill and stop losses decrease | High SOC and battery limits reduce actual regeneration |
| `drivetrain_efficiency` | Battery energy falls | Must remain in a physically plausible range |
| `auxiliary_power_kw` | Energy grows with journey time | Temperature effects should not be double-counted |
| `full_stop_count` | Stop-start losses increase | A route provider may supply an estimate, not exact future stops |

## 5. Safety-first reachability logic

Display range is not enough for charger reachability. VoltEZ should calculate:

`usable capacity = battery capacity x usable-capacity fraction`

`energy above reserve = usable capacity x (current SOC - reserve SOC) / 100`

`safety margin = energy above reserve - conservative P90 route energy`

The route is:

- `unreachable` when the safety margin is negative;
- `borderline` when the positive margin is no larger than the greater of 0.5 kWh or 3% of usable
  capacity;
- `reachable` otherwise.

The application must use P90 energy for the safety decision, not only the expected value. Expected
energy is useful for display and ranking; conservative energy protects drivers against
underprediction.

## 6. Application database additions

The current design already has vehicles, SOC fields, trips, distance, detours, and charger options.
The following additions should be reviewed by the backend/database team before implementation.
They are proposed for the whole application, not only offline ML.

### 6.1 `vehicle_energy_profiles`

Versioned optional specifications:

- `vehicle_id`, `effective_from`, `effective_to`, `source`, `confidence`;
- curb mass, default payload, drag coefficient, frontal area or combined drag area;
- rolling-resistance coefficient;
- drivetrain and regenerative-braking efficiencies;
- usable-capacity and battery-health fractions.

Keeping this versioned prevents a later specification correction from rewriting historical route
predictions.

### 6.2 `route_snapshots`

Immutable provider response used for one planning decision:

- trip/request ID, provider, provider route ID/hash, requested/generated timestamps;
- origin/destination references with restricted coordinate retention;
- distance, normal duration, traffic duration, route polyline reference;
- elevation gain/loss and grade summaries;
- urban/highway fractions and estimated stops;
- source freshness, quality, and expiry.

Every prediction references a route snapshot. The backend must not recompute historical features
from a newer route response.

### 6.3 `route_energy_observations`

Real labels and audit evidence:

- route snapshot, trip, vehicle, start/end timestamps;
- start/end SOC and usable-capacity snapshot;
- battery-energy-out kWh when telemetry is available;
- label source, confidence, known/unknown state, and quality flags.

Exact route coordinates remain operational data and should not enter training exports. Training
uses derived route summaries and non-reversible identifiers.

## 7. Training-dataset contract

### 7.1 Lineage and metadata - never model features

- observation, trip, route-snapshot, vehicle, candidate charger, and simulation IDs;
- feature view and label definition versions;
- route snapshot time, feature cutoff, label time, split, and evaluation role;
- label source and confidence.

These fields make rows auditable. IDs must not be used as predictive inputs.

### 7.2 Vehicle features

- vehicle class, battery and usable-capacity values;
- total mass including estimated payload;
- drag area and rolling-resistance prior;
- drivetrain and regeneration efficiency priors;
- battery-health fraction;
- current and reserve SOC.

### 7.3 Route features

- distance, duration, traffic-delay ratio;
- elevation gain/loss and grade summaries;
- full-stop estimate;
- urban/highway fractions;
- route provider and source-quality category where useful.

### 7.4 Environment features

- ambient temperature, precipitation, headwind, and air density;
- road-surface state;
- estimated auxiliary load;
- fetch/source timestamps converted to age or freshness features.

Only context published and ingested before `route_snapshot_at` is permitted.

### 7.5 Baseline features

- nominal `efficiency_wh_per_km x distance` estimate;
- total physics estimate;
- every physics component.

The residual model can learn when a component is systematically wrong without relearning the
component from raw variables alone.

### 7.6 Labels

Preferred label order:

1. directly measured battery-energy-out telemetry;
2. BMS SOC delta combined with a contemporaneous usable-capacity estimate;
3. synthetic hidden segment-level truth during development.

Rows without trustworthy start/end evidence remain `unknown` and are excluded from supervised
fitting. Unknown must not be converted to zero energy.

## 8. Preventing a formula-only synthetic model

The public baseline and hidden label generator must not be identical.

The hidden truth engine will simulate 30-second route segments with:

- a speed trace rather than one mean speed;
- acceleration and braking events;
- SOC-dependent regeneration limits;
- hidden driver aggressiveness;
- manufacturing variation in drag, rolling resistance, and drivetrain efficiency;
- payload/passenger variation;
- nonlinear HVAC and battery thermal load;
- battery-health and usable-capacity variation;
- elevation and wind variation along the route;
- measurement error in provider route summaries.

Training features receive only aggregate, noisy values that the real application could know at
planning time. Hidden true coefficients and segment traces live in QA-only tables and are forbidden
from features.

This separation means the future residual model must generalize relationships instead of copying a
single label equation.

## 9. Required synthetic scenarios

| Scenario | Variation required | Why it matters |
|---|---|---|
| Normal Pune urban | Moderate speed, frequent stops, short routes | Main marketplace behavior |
| Highway | Higher speed and drag, fewer stops | Tests aerodynamic sensitivity |
| Mixed route | Urban + highway segments | Common route-to-charger case |
| Monsoon | Wet-road resistance, slower traffic, HVAC/wipers | Existing VoltEZ stress scenario |
| Congestion | Long duration, stop-start behavior | Separates time load from distance |
| Steep route | Elevation gain/loss and regen limits | Tests gravitational terms |
| Heavy payload | More rolling/climbing/acceleration energy | Commercial and multi-passenger use |
| Battery degradation | Reduced usable capacity | Critical reachability risk |
| Cold-start specification | Missing vehicle physics fields | Exercises fallback priors and quality state |
| Provider error | Noisy duration/elevation/stop estimate | Tests real integration uncertainty |
| Missing context | No weather/elevation enrichment | Ensures a safe baseline fallback |

Worlds must vary hidden coefficients and scenario mixture, not only random row order.

## 10. Splitting and leakage rules

Use the existing five-world strategy:

- two independent training worlds;
- one validation world for model and policy choices;
- one locked test world;
- one stress world with structural/context shift.

The Model 5 trainer must have no `--unlock-test` option during development. Real-data evaluation
later uses chronological cutoffs and reports new-vehicle, known-vehicle, route-type, distance, SOC,
weather, elevation, and traffic slices separately.

Forbidden inputs include IDs, realized arrival SOC, measured energy, end time, final route duration,
post-trip weather, label metadata, QA latent coefficients, hidden driver behavior, and segment speed
traces unavailable during planning.

## 11. Planned baselines and candidates

No fitting occurs in Step 1. The later comparison will be:

1. **Nominal efficiency baseline** - `distance x vehicle efficiency_wh_per_km`.
2. **Aggregate physics baseline** - the implemented deterministic component formula.
3. **Mean residual model** - histogram gradient boosting predicts
   `actual energy - physics estimate`.
4. **P50/P90 residual models** - quantile variants provide typical and conservative energy.

The final mean prediction is clipped to nonnegative energy. Quantile outputs must also satisfy:

`expected/P50 energy <= P90 energy`

If a candidate cannot materially beat physics or damages safety, VoltEZ should deploy physics only.
Using fewer models is better than deploying unjustified ML.

## 12. Evaluation plan

### 12.1 Energy accuracy

- MAE and RMSE in kWh;
- WAPE for fleet-level error;
- signed bias and bias as a fraction of mean energy;
- arrival-SOC MAE in percentage points;
- comparison with nominal-efficiency and physics baselines.

MAPE is not a headline metric because tiny-energy routes can create meaningless percentages.

### 12.2 Uncertainty and safety

- P90 empirical coverage and interval width;
- false-safe rate: predicted reachable but actual arrival falls below reserve;
- false-unreachable rate and borderline rate;
- fallback/unknown rate;
- worst underprediction and 95th-percentile underprediction.

### 12.3 Required slices

- vehicle class and cold-start profile;
- distance and current-SOC bands;
- urban/highway mix;
- elevation, traffic, and weather bands;
- battery-health bands;
- normal versus stress worlds.

### 12.4 Provisional development gates

- at least 5% MAE improvement over nominal-efficiency baseline;
- at least 3% MAE improvement over physics to justify deploying ML correction;
- absolute mean bias no greater than 2% of mean target energy;
- P90 coverage between 88% and 94%;
- false-safe rate no greater than 1% on validation and 2% on stress;
- 100% finite, nonnegative predictions;
- at least 250 rows before treating a slice metric as a gate.

These gates may be tightened before training, but they must not be weakened after viewing locked-test
results.

## 13. M4 hardware plan

The deterministic baseline is ordinary CPU arithmetic. The planned histogram-gradient-boosting and
quantile candidates use the Apple M4 CPU. Scikit-learn does not use MPS for these estimators, so no
fake GPU flag should be enabled. Data will be generated and built sequentially under the existing
10 GB memory budget.

## 14. Sponsor roles

- **Google route services:** real distance, traffic-aware duration, route geometry, and elevation
  enrichment through a timestamped adapter.
- **Swytchcode:** governed execution, provenance, and fallback behavior for external route/context
  calls.
- **Tavily:** source discovery for weather, road, and public-context providers; never a direct label
  generator.
- **CodeMate AI:** review unit conversions, physical invariants, leakage checks, and serving code.
- **Render:** host the future inference bundle and health/version endpoints.
- **n8n:** orchestrate route-context freshness monitoring and approved evaluation workflows.
- **Gemini/Lyzr:** explain why a route is borderline using approved numeric components; never change
  reachability or energy values.

Sponsor credentials are not required in Step 1. Adapters must retain a deterministic fallback so a
sponsor outage does not make route planning impossible.

## 15. Step sequence from here

1. Step 1A - review and freeze this physics/data/evaluation design.
2. Step 2 - extend schema-compatible synthetic route and vehicle profiles.
3. Step 3 - implement hidden segment-level energy truth and validation invariants.
4. Step 4 - build leakage-safe route-energy feature views for all worlds.
5. Step 5 - audit readiness and baselines without opening test.
6. Step 6 - train mean and quantile residual candidates locally on the M4.
7. Step 7 - evaluate validation/stress, freeze a candidate, then request explicit locked-test
   approval.
8. Step 8 - build the FastAPI serving bundle and shadow-monitoring contract.

## 16. Knowledge check

1. Why should VoltEZ predict a residual around physics instead of only fitting a black-box model?
2. Why is vehicle display range not sufficient for reachability?
3. Why does aerodynamic energy grow strongly with speed?
4. Why can a downhill route still consume positive net energy?
5. Why must reachability use P90 rather than only expected energy?
6. Which hidden synthetic variables would cause target leakage if exported as features?
7. Why is MAPE unstable for very short routes?
8. When should VoltEZ choose the physics baseline instead of deploying the ML correction?
