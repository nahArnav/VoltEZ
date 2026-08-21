# VoltEZ ML documentation map

Read these documents in build order. Generated datasets, feature snapshots, and model artifacts do
not belong in this directory.

| Stage | Document | Purpose |
|---|---|---|
| Foundation | `project_foundation.md` | Repository layout, configuration layers, and local workflow |
| Environment | `local_environment.md` | Apple M4 setup and hardware verification |
| Backend contract | `database_schema.md` | Full application schema and invariants |
| Schema update | `schema_reconciliation_v1_1.md` | Mapping from schema v1.1 to synthetic and ML tables |
| ML contract | `ml_data_contract.md` | Labels, cutoffs, features, and serving contract |
| Step 5 | `synthetic_generator.md` | Synthetic-world logic and validation |
| Step 6 | `feature_engineering.md` | Point-in-time features and leakage prevention |
| Step 7 | `experiment_readiness.md` | Independent seeds and evaluation-role isolation |
| Step 8 | `rehearsal_results.md` | Five-world rehearsal measurements and next gates |
| Step 9 | `model_training_handoff.md` | Models 3/4 data, final suite, and Model 1 training |

The repository root `README.md` remains the short operational entry point. This index keeps the
detailed engineering narrative discoverable without crowding the root.
