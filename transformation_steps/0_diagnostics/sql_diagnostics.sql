-- Diagnostics for validation mismatches.
--
-- Run this after creating the materialized views. It does not modify data.
-- Use it to identify where totals get bigger:
-- 1. source scope
-- 2. account mapping fanout
-- 3. ASP lookup fanout

-- A. Source month scope before any joins.
select
    'A_source_export' as check_name,
    left(replace(e."Sell-out Month"::text, ',', ''), 4) as year,
    min(nullif(replace(e."Sell-out Month"::text, ',', ''), '')::bigint) as min_month,
    max(nullif(replace(e."Sell-out Month"::text, ',', ''), '')::bigint) as max_month,
    count(*) as rows,
    sum(nullif(replace(e."Active"::text, ',', ''), '')::numeric) as active_qty
from "Zahab"."ASAP Export_1st and 2nd Activation" e
where e."Sell-in Region" = 'MIDDLE EAST'
group by
    left(replace(e."Sell-out Month"::text, ',', ''), 4)
union all
select
    'A_source_import' as check_name,
    left(replace(i."Sell-out Month"::text, ',', ''), 4) as year,
    min(nullif(replace(i."Sell-out Month"::text, ',', ''), '')::bigint) as min_month,
    max(nullif(replace(i."Sell-out Month"::text, ',', ''), '')::bigint) as max_month,
    count(*) as rows,
    sum(nullif(replace(i."Active"::text, ',', ''), '')::numeric) as active_qty
from "Zahab"."ASAP Import_1st and 2nd Activation" i
where i."Sell-in Region" <> 'Grand total'
  and i."Current Region" = 'MIDDLE EAST'
group by
    left(replace(i."Sell-out Month"::text, ',', ''), 4)
order by
    check_name,
    year;

-- B. Account mapping duplicate keys. Any row here can multiply Step 1 rows.
select
    'B_account_mapping_duplicate_keys' as check_name,
    am."Subsidiary",
    am."OrgSales",
    count(*) as duplicate_rows
from bi_reporting.account_mapping am
group by
    am."Subsidiary",
    am."OrgSales"
having count(*) > 1
order by
    duplicate_rows desc,
    am."Subsidiary",
    am."OrgSales";

-- C. Account join multiplier by side and year.
select
    joined.side,
    joined.year,
    count(*) as rows_after_join,
    count(distinct joined.row_key) as rows_before_join,
    count(*) - count(distinct joined.row_key) as added_rows
from (
    select
        'export' as side,
        left(replace(e."Sell-out Month"::text, ',', ''), 4) as year,
        e.ctid::text as row_key
    from "Zahab"."ASAP Export_1st and 2nd Activation" e
    left join bi_reporting.account_mapping am
        on am."Subsidiary" = e."Sell-in Sub"
       and am."OrgSales" = e."Sell-in Account"
    where e."Sell-in Region" = 'MIDDLE EAST'
    union all
    select
        'import' as side,
        left(replace(i."Sell-out Month"::text, ',', ''), 4) as year,
        i.ctid::text as row_key
    from "Zahab"."ASAP Import_1st and 2nd Activation" i
    left join bi_reporting.account_mapping am
        on am."Subsidiary" = i."Sell-in Sub"
       and am."OrgSales" = i."Sell-in Account"
    where i."Sell-in Region" <> 'Grand total'
      and i."Current Region" = 'MIDDLE EAST'
) joined
group by
    joined.side,
    joined.year
order by
    joined.side,
    joined.year;

-- D. Step row counts by year. Counts should not increase after Step 1.
select
    'D_step1' as check_name,
    "Year" as year,
    count(*) as rows,
    sum("Active Qty") as active_qty,
    sum("Total Inflow") as total_inflow,
    sum("Total Outflow") as total_outflow
from bi_reporting.io_1_quantity_mv
group by
    "Year"
union all
select
    'D_step2' as check_name,
    "Year" as year,
    count(*) as rows,
    sum("Active Qty") as active_qty,
    sum("Total Inflow") as total_inflow,
    sum("Total Outflow") as total_outflow
from bi_reporting.io_2_asp_mv
group by
    "Year"
union all
select
    'D_step3' as check_name,
    "Year" as year,
    count(*) as rows,
    sum("Active Qty") as active_qty,
    sum("Total Inflow") as total_inflow,
    sum("Total Outflow") as total_outflow
from bi_reporting.io_3_amount_mv
group by
    "Year"
order by
    year,
    check_name;

-- E. ASP lookup duplicate keys before de-duplication.
select
    'E_series_asp_duplicate_keys' as check_name,
    series as key_1,
    category as key_2,
    count(*) as rows
from bi_reporting.series_asp_mv
group by
    series,
    category
having count(*) > 1
union all
select
    'E_global_asp_duplicate_keys' as check_name,
    "Biz Group"::text as key_1,
    "Category"::text as key_2,
    count(*) as rows
from "Zahab"."Sell-out Biz Plan Global_ASP"
where "Category" <> 'DELTA'
group by
    "Biz Group",
    "Category"
having count(*) > 1
order by
    check_name,
    rows desc,
    key_1,
    key_2;
