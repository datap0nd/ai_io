# Transformation Steps

Run and validate one folder at a time.

Each step has four simple files:

- `view.sql`: creates the PostgreSQL materialized view for that step.
- `power_query.m`: Power Query Advanced Editor code.
- `model.tmdl`: TMDL script for the semantic model changes.
- `validate.dax`: DAX query to run before and after the step.

## Order

0. `0_diagnostics`: mismatch diagnostics only, including the 2025 overall validation.
1. `1_quantity`: core quantity logic for `Global_Inflow_Outflow`.
2. `2_asp`: adds ASP lookup logic.
3. `3_amount`: adds amount columns and amount-aware measures.
4. `4_date`: moves `Month Map` into SQL.

Do not move to the next step until the current step validates exactly.

## Diagnostics

- `0_diagnostics/overall_2025.dax`: broad 2025 validation for frozen vs SQL-backed model comparisons.

## Power BI Calculated Column Rule

Some SQL views include columns that already exist in the Power BI model as
calculated columns, such as `Across Sub`, `Parallel S/O`, amount columns, and
`Month Map[Date]`.

The Power Query files intentionally do not import those duplicate column names.
The TMDL files keep or restore them as calculated columns. Importing them before
deleting the existing calculated columns causes invalid bindings or duplicate-name
errors in Power BI.

## Validation Caveats

Step 2 uses `bi_reporting.series_asp_mv` as the SQL-side replacement for the
Power BI `Series_ASP_Year` Excel logic. Validate Step 2 carefully by year and
business group before trusting amount metrics. If the SQL series ASP source does
not contain the same category years as the Excel file, ASP parity will fail.

Step 3 computes amount columns in SQL for validation, but the model script keeps
the existing calculated-column names in Power BI to avoid duplicate binding
errors. Treat SQL amount import as a separate migration only after Step 3
matches.
