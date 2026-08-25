# Step 8 — Five-world rehearsal results

## Outcome

The corrected two-day Pune rehearsal completed successfully. Five independently seeded worlds
were generated sequentially, combined into point-in-time features, and checked by both the core
feature audit and the Step 8 lineage/distribution audit. No model was fitted.

The core feature audit passed with zero failures and zero warnings. The rehearsal-specific audit
passed with expected small-sample warnings that must become hard gates before full training.

Artifacts are organized under the ignored directory:

```text
data/rehearsals/step_08/
├── synthetic/                 five immutable simulation-run directories
├── processed/                 one combined feature snapshot
└── rehearsal_audit.json       machine-readable Step 8 report
```

They do not appear in Git status and are not intended for GitHub.

## Resource measurements on Apple M4 / 16 GB

| Stage | Wall time | Peak RSS | Result |
|---|---:|---:|---|
| Train seed 01 | 0.39 s | 113.5 MiB | passed |
| Train seed 02 | 0.39 s | 113.3 MiB | passed |
| Validation seed 01 | 0.39 s | 113.6 MiB | passed |
| Locked test seed 01 | 0.39 s | 113.3 MiB | passed |
| Stress seed 01 | 0.44 s | 114.1 MiB | passed |
| Combined feature build | 1.29 s | 179.9 MiB | passed |

The complete rehearsal occupies approximately 1.77 MiB on disk. These figures describe the tiny
two-day profile only. They cannot be multiplied linearly to promise that five 90-day runs will fit
in memory. The conservative full-profile preflight warning remains valid.

## Raw-world variation

| Role | Requests | Bookings | Sessions | Availability observations |
|---|---:|---:|---:|---:|
| Train seed 01 | 100 | 48 | 41 | 162 |
| Train seed 02 | 87 | 33 | 29 | 79 |
| Validation | 90 | 52 | 42 | 143 |
| Locked test | 76 | 47 | 39 | 103 |
| Stress test | 115 | 62 | 42 | 182 |

The two training seeds differ while sharing the exact same causal parameters. That is desired:
the future model must learn repeatable relationships rather than one exact list of requests.

## Feature output

Feature snapshot: `features-927eb7858d827a18c5f4`

| Table | Rows |
|---|---:|
| Demand features | 16,460 |
| Availability features, including unknown truth | 624 |
| Availability supervised rows | 205 |

Every feature row retained the experiment role from its source manifest. The locked test world is
`test` on every row and the stress world is `stress_test` on every row, regardless of the internal
chronological `split` value.

### Demand by independent-world role

| Role | Rows | Mean target requests | Zero-target rate |
|---|---:|---:|---:|
| Train | 6,584 | 0.124 | 88.59% |
| Validation | 3,292 | 0.118 | 89.00% |
| Locked test | 3,292 | 0.101 | 91.04% |
| Stress test | 3,292 | 0.150 | 86.57% |

Fifteen-minute zone buckets are naturally sparse. Model 1 therefore needs count-aware baselines
and metrics; plain accuracy would be meaningless because predicting zero often would look good.
The stress world correctly has a higher mean and lower zero rate than the ordinary training worlds.

### Availability by independent-world role

| Role | All rows | Known labels | Unknown rate | Cold-start rate | Available | Unavailable |
|---|---:|---:|---:|---:|---:|---:|
| Train | 225 | 70 | 68.89% | 100.00% | 67 | 3 |
| Validation | 133 | 43 | 67.67% | 95.49% | 41 | 2 |
| Locked test | 97 | 35 | 63.92% | 97.94% | 34 | 1 |
| Stress test | 169 | 57 | 66.27% | 91.12% | 45 | 12 |

Unknown is correctly retained as a third truth state and removed only from supervised Model 2
rows. The high unknown and cold-start rates are expected from a two-day world, but the baseline
unavailable class is too small for trustworthy training or test metrics. The 90-day gate must
require adequate class support separately for train, validation, and locked test roles.

## Correctness corrections discovered during rehearsal

### Timezone-aware nullable timestamps

Strict warnings-as-errors testing found that an entirely null `bookings.hold_expires_at` column
was being inferred as timezone-naive. The generator now normalizes every booking timestamp to
`datetime64[ns, Asia/Kolkata]`, matching the PostgreSQL `TIMESTAMPTZ` rule. The five worlds and
feature snapshot were rebuilt after this correction.

This is exactly why a rehearsal exists: catch schema and scaling problems before a long run or a
model can hide them.

### Keyed demand targets

A strict full-row target check exposed that demand labels had been assigned from a grouped Series
by pandas row position after a merge. Merge ordering is not a stable contract, so a future bucket
from the wrong row could silently become the label. The builder now joins targets explicitly on
`simulation_run_id`, `zone_id`, and `target_time`. The strengthened test compares every produced
feature row with the raw future demand bucket, not one sample.

The corrected dataset contains fewer demand rows because end-of-history targets are now removed
within their own zone and horizon instead of inheriting a non-null value from another position.

## What the warnings mean

1. **Unknown availability above 50%:** two days do not provide enough evidence to label every
   future arrival honestly. Unknown rows must never be converted to unavailable.
2. **Cold starts above 50%:** port reliability needs longer history. A 90-day profile should reduce
   this sharply, but the cold-start flag remains a feature.
3. **Small baseline minority class:** train, validation, and test contain only 3, 2, and 1 known
   unavailable examples respectively. Model 2 training is blocked until full-profile class support
   is measured and approved.
4. **Dirty-worktree lineage:** the first rehearsal was intentionally produced before the Step 8
   implementation was committed, so its source manifest recorded a dirty tree. The approved
   post-commit refresh replaces those local rehearsal artifacts with clean-commit manifests. The
   machine-readable `rehearsal_audit.json` is the final source of truth for that check.

## Step 9 recommendation

Do not train yet. First implement and test partitioned feature assembly for the full 90-day runs,
because the current conservative combined-memory estimate is above the 10 GB project budget.
Then generate one full training seed, measure actual disk/RSS/class support, and decide whether to
continue with the remaining worlds.

Sponsor integrations remain outside the statistical truth path. n8n can orchestrate sequential
generation after credentials arrive; CodeMate AI can review the leakage and audit code; Render can
host later FastAPI inference. None may rewrite labels, manifests, or evaluation roles.
