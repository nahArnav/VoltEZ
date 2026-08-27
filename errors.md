# Codebase Errors

## Backend (Ruff)
```text
All checks passed!
```

## Pyright
```text
/home/altron/Desktop/Projects/VoltEZ/backend/alembic/env.py
  /home/altron/Desktop/Projects/VoltEZ/backend/alembic/env.py:54:9 - error: Argument of type "str | None" cannot be assigned to parameter "url" of type "str | URL" in function "create_engine"
    Type "str | None" is not assignable to type "str | URL"
      Type "None" is not assignable to type "str | URL"
        "None" is not assignable to "str"
        "None" is not assignable to "URL" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/alembic/versions/bc0142eb44ea_link_bookings_to_search_results.py
  /home/altron/Desktop/Projects/VoltEZ/backend/alembic/versions/bc0142eb44ea_link_bookings_to_search_results.py:45:24 - error: Argument of type "None" cannot be assigned to parameter "constraint_name" of type "str" in function "drop_constraint"
    "None" is not assignable to "str" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/businesses.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/businesses.py:67:14 - error: Cannot assign to attribute "latitude" for class "Business"
    Attribute "latitude" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/businesses.py:68:14 - error: Cannot assign to attribute "longitude" for class "Business"
    Attribute "longitude" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/businesses.py:134:18 - error: Cannot assign to attribute "latitude" for class "Business"
    Attribute "latitude" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/businesses.py:135:18 - error: Cannot assign to attribute "longitude" for class "Business"
    Attribute "longitude" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/charger.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/charger.py:176:38 - error: Argument of type "UUID[Unknown]" cannot be assigned to parameter "charger_id" of type "UUID" in function "_require_owned_charger"
    "UUID[Unknown]" is not assignable to "UUID" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/payments.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/api/v1/payments.py:99:37 - error: Cannot access attribute "order" for class "Client"
    Attribute "order" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/app/ml/adapters.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/ml/adapters.py:65:30 - error: Argument of type "dict[Hashable, Any]" cannot be assigned to parameter "features" of type "dict[str, float | None]" in function "__init__"
    "dict[Hashable, Any]" is not assignable to "dict[str, float | None]"
      Type parameter "_KT@dict" is invariant, but "Hashable" is not the same as "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/app/ml/adapters.py:116:30 - error: Argument of type "dict[Hashable, Any]" cannot be assigned to parameter "features" of type "dict[str, FeatureValue]" in function "__init__"
    "dict[Hashable, Any]" is not assignable to "dict[str, FeatureValue]"
      Type parameter "_KT@dict" is invariant, but "Hashable" is not the same as "str" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/app/repositories/base.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/repositories/base.py:21:31 - error: Cannot access attribute "id" for class "type[Base]*"
    Attribute "id" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/app/services/charger.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/services/charger.py:43:20 - error: Cannot assign to attribute "latitude" for class "Charger"
    Attribute "latitude" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/app/services/charger.py:44:20 - error: Cannot assign to attribute "longitude" for class "Charger"
    Attribute "longitude" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/app/services/fcm.py
  /home/altron/Desktop/Projects/VoltEZ/backend/app/services/fcm.py:31:26 - error: "get" is not a known attribute of "None" (reportOptionalMemberAccess)
  /home/altron/Desktop/Projects/VoltEZ/backend/app/services/fcm.py:31:46 - error: "get" is not a known attribute of "None" (reportOptionalMemberAccess)
/home/altron/Desktop/Projects/VoltEZ/backend/database/models/charger.py
  /home/altron/Desktop/Projects/VoltEZ/backend/database/models/charger.py:116:24 - error: "orm" is not a known attribute of module "sqlalchemy" (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/database/models/charger_port.py
  /home/altron/Desktop/Projects/VoltEZ/backend/database/models/charger_port.py:62:26 - error: "orm" is not a known attribute of module "sqlalchemy" (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/database/models/vehicle.py
  /home/altron/Desktop/Projects/VoltEZ/backend/database/models/vehicle.py:85:34 - error: "orm" is not a known attribute of module "sqlalchemy" (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/scripts/seed_demo.py
  /home/altron/Desktop/Projects/VoltEZ/backend/scripts/seed_demo.py:24:6 - error: Import "app.models" could not be resolved (reportMissingImports)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/evaluation/demand.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/evaluation/demand.py:362:28 - error: Cannot access attribute "importances_mean" for class "dict[Unknown, Bunch]"
    Attribute "importances_mean" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/evaluation/demand.py:363:28 - error: Cannot access attribute "importances_std" for class "dict[Unknown, Bunch]"
    Attribute "importances_std" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:291:30 - error: Argument of type "list[bool]" cannot be assigned to parameter "categorical_features" of type "str" in function "__init__"
    "list[bool]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:292:24 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:443:96 - error: Argument of type "Literal[0]" cannot be assigned to parameter "zero_division" of type "str" in function "precision_score"
    "Literal[0]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:444:90 - error: Argument of type "Literal[0]" cannot be assigned to parameter "zero_division" of type "str" in function "recall_score"
    "Literal[0]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:445:82 - error: Argument of type "Literal[0]" cannot be assigned to parameter "zero_division" of type "str" in function "f1_score"
    "Literal[0]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:646:26 - error: Cannot access attribute "importances_mean" for class "dict[Unknown, Bunch]"
    Attribute "importances_mean" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/availability.py:646:51 - error: Cannot access attribute "importances_std" for class "dict[Unknown, Bunch]"
    Attribute "importances_std" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand.py:200:24 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand_hurdle.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand_hurdle.py:133:28 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand_hurdle.py:142:28 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand_window.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/demand_window.py:191:24 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:291:30 - error: Argument of type "list[bool]" cannot be assigned to parameter "categorical_features" of type "str" in function "__init__"
    "list[bool]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:292:24 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:443:95 - error: Argument of type "Literal[0]" cannot be assigned to parameter "zero_division" of type "str" in function "precision_score"
    "Literal[0]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:444:89 - error: Argument of type "Literal[0]" cannot be assigned to parameter "zero_division" of type "str" in function "recall_score"
    "Literal[0]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:445:81 - error: Argument of type "Literal[0]" cannot be assigned to parameter "zero_division" of type "str" in function "f1_score"
    "Literal[0]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:644:26 - error: Cannot access attribute "importances_mean" for class "dict[Unknown, Bunch]"
    Attribute "importances_mean" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/reliability.py:644:51 - error: Cannot access attribute "importances_std" for class "dict[Unknown, Bunch]"
    Attribute "importances_std" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/waiting_time.py
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/waiting_time.py:218:28 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/waiting_time.py:219:34 - error: Argument of type "list[int] | None" cannot be assigned to parameter "categorical_features" of type "str" in function "__init__"
    Type "list[int] | None" is not assignable to type "str"
      "list[int]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/waiting_time.py:229:28 - error: Argument of type "Literal[False]" cannot be assigned to parameter "early_stopping" of type "str" in function "__init__"
    "Literal[False]" is not assignable to "str" (reportArgumentType)
  /home/altron/Desktop/Projects/VoltEZ/backend/src/voltez_ml/training/waiting_time.py:230:34 - error: Argument of type "list[int] | None" cannot be assigned to parameter "categorical_features" of type "str" in function "__init__"
    Type "list[int] | None" is not assignable to type "str"
      "list[int]" is not assignable to "str" (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/tests/integration/test_booking_flow.py
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/integration/test_booking_flow.py:115:38 - error: Cannot access attribute "order" for class "Client"
    Attribute "order" is unknown (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/integration/test_booking_flow.py:118:38 - error: Cannot access attribute "utility" for class "Client"
    Attribute "utility" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/tests/test_demand_hurdle.py
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_demand_hurdle.py:37:11 - error: Cannot assign to attribute "occurrence_model_" for class "HurdleDemandRegressor"
    Expression of type "_OccurrenceStub" cannot be assigned to attribute "occurrence_model_" of class "HurdleDemandRegressor"
      "_OccurrenceStub" is not assignable to "HistGradientBoostingClassifier" (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_demand_hurdle.py:38:11 - error: Cannot assign to attribute "positive_count_model_" for class "HurdleDemandRegressor"
    Expression of type "_PositiveCountStub" cannot be assigned to attribute "positive_count_model_" of class "HurdleDemandRegressor"
      "_PositiveCountStub" is not assignable to "HistGradientBoostingRegressor" (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/tests/test_demand_serving.py
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_demand_serving.py:146:89 - error: Argument of type "dict[str, float]" cannot be assigned to parameter "features" of type "dict[str, float | None]" in function "__init__"
    "dict[str, float]" is not assignable to "dict[str, float | None]"
      Type parameter "_VT@dict" is invariant, but "float" is not the same as "float | None"
      Consider switching from "dict" to "Mapping" which is covariant in the value type (reportArgumentType)
/home/altron/Desktop/Projects/VoltEZ/backend/tests/test_feature_suite.py
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_feature_suite.py:104:22 - error: "subprocess" is not exported from module "voltez_ml.features.suite" (reportPrivateImportUsage)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_feature_suite.py:112:22 - error: "subprocess" is not exported from module "voltez_ml.features.suite" (reportPrivateImportUsage)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_feature_suite.py:121:22 - error: "subprocess" is not exported from module "voltez_ml.features.suite" (reportPrivateImportUsage)
/home/altron/Desktop/Projects/VoltEZ/backend/tests/test_features.py
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_features.py:76:5 - error: Operator "+=" not supported for types "Scalar" and "Literal[10000]"
    Operator "+" not supported for types "str" and "Literal[10000]"
    Operator "+" not supported for types "bytes" and "Literal[10000]"
    Operator "+" not supported for types "date" and "Literal[10000]"
    Operator "+" not supported for types "datetime" and "Literal[10000]"
    Operator "+" not supported for types "timedelta" and "Literal[10000]"
    Operator "+" not supported for types "Timestamp" and "Literal[10000]"
    Operator "+" not supported for types "Timedelta" and "Literal[10000]" (reportOperatorIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_features.py:315:27 - error: Cannot access attribute "startswith" for class "Hashable"
    Attribute "startswith" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/backend/tests/test_waiting_time_training.py
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_waiting_time_training.py:34:11 - error: Cannot assign to attribute "occurrence_model_" for class "HurdleWaitingTimeRegressor"
    Expression of type "_OccurrenceStub" cannot be assigned to attribute "occurrence_model_" of class "HurdleWaitingTimeRegressor"
      "_OccurrenceStub" is not assignable to "HistGradientBoostingClassifier" (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_waiting_time_training.py:35:11 - error: Cannot assign to attribute "positive_count_model_" for class "HurdleWaitingTimeRegressor"
    Expression of type "_PositiveCountStub" cannot be assigned to attribute "positive_count_model_" of class "HurdleWaitingTimeRegressor"
      "_PositiveCountStub" is not assignable to "HistGradientBoostingRegressor" (reportAttributeAccessIssue)
  /home/altron/Desktop/Projects/VoltEZ/backend/tests/test_waiting_time_training.py:36:11 - error: Cannot assign to attribute "n_features_in_" for class "HurdleWaitingTimeRegressor"
    Attribute "n_features_in_" is unknown (reportAttributeAccessIssue)
/home/altron/Desktop/Projects/VoltEZ/frontend/ios/Flutter/ephemeral/flutter_lldb_helper.py
  /home/altron/Desktop/Projects/VoltEZ/frontend/ios/Flutter/ephemeral/flutter_lldb_helper.py:5:8 - error: Import "lldb" could not be resolved (reportMissingImports)
57 errors, 0 warnings, 0 informations
```

## Frontend (Flutter)
```text
bash: line 1: flutter: command not found
```
