# Transformation Steps

Run and validate one folder at a time.

Each step has four simple files:

- `view.sql`: creates the PostgreSQL materialized view for that step.
- `power_query.m`: Power Query Advanced Editor code.
- `model.tmdl`: TMDL script for the semantic model changes.
- `validate.dax`: DAX query to run before and after the step.

## Order

1. `1_quantity`: core quantity logic for `Global_Inflow_Outflow`.
2. `2_asp`: adds ASP lookup logic.
3. `3_amount`: adds amount columns and amount-aware measures.
4. `4_date`: moves `Month Map` into SQL.

Do not move to the next step until the current step validates exactly.
