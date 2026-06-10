-- 2025 import-side SQL triage.
--
-- Purpose:
-- Diagnose the pattern where S/O SCM and Total Outflow match, but Total
-- Inflow and Domestic Demand do not.
--
-- This file does not modify persistent data. It uses temp tables only.
--
-- Read the result sets in this order:
-- 1. source_scope_by_inout_mkt_status
-- 2. account_mapping_duplicate_keys_hit
-- 3. account_join_fanout_by_inout
-- 4. joined_totals_current_step_logic
-- 5. materialized_view_import_totals

drop table if exists pg_temp.io_diag_import_2025_source;
drop table if exists pg_temp.io_diag_import_2025_after_current_mkt_filter;
drop table if exists pg_temp.io_diag_import_2025_after_strict_mkt_filter;
drop table if exists pg_temp.io_diag_import_2025_account_hits;
drop table if exists pg_temp.io_diag_import_2025_joined;
drop table if exists pg_temp.io_diag_import_2025_fanout;

-- Source import rows using the Power Query source-scope filters for 2025.
create temp table io_diag_import_2025_source as
select
    i.ctid::text as row_key,
    i."Sell-in Region"::text as sell_in_region,
    i."Sell-in Sub"::text as sell_in_sub,
    i."Sell-in Account"::text as sell_in_account,
    i."Sell-out Region"::text as sell_out_region,
    i."Sell-out Sub"::text as sell_out_sub,
    i."Current Region"::text as current_region,
    i."Current Sub"::text as current_sub,
    i."MKT Name"::text as mkt_name,
    nullif(replace(i."Sell-out Month"::text, ',', ''), '')::bigint as month,
    left(replace(i."Sell-out Month"::text, ',', ''), 4) as year,
    nullif(replace(i."Active"::text, ',', ''), '')::numeric as active_qty,
    case
        when i."Sell-in Sub" is not distinct from i."Current Sub" then 'Domestic-I'
        else 'Inflow'
    end as in_out,
    case
        when i."MKT Name" is null then 'blank_mkt_name'
        when i."MKT Name" in ('Galaxy Z Fold Special Edition', 'W25', 'W25 Flip') then 'excluded_model'
        else 'kept_model'
    end as mkt_status
from "Zahab"."ASAP Import_1st and 2nd Activation" i
where i."Sell-in Region" <> 'Grand total'
  and i."Current Region" = 'MIDDLE EAST'
  and left(replace(i."Sell-out Month"::text, ',', ''), 4) = '2025';

-- Current Step 1 SQL keeps blank MKT Name rows.
create temp table io_diag_import_2025_after_current_mkt_filter as
select *
from io_diag_import_2025_source
where mkt_name is null
   or mkt_name not in ('Galaxy Z Fold Special Edition', 'W25', 'W25 Flip');

-- Strict variant drops blank MKT Name rows. This is for diagnosis only.
create temp table io_diag_import_2025_after_strict_mkt_filter as
select *
from io_diag_import_2025_source
where mkt_name not in ('Galaxy Z Fold Special Edition', 'W25', 'W25 Flip');

-- Account mapping keys hit by the filtered 2025 import rows.
create temp table io_diag_import_2025_account_hits as
select
    s.row_key,
    s.in_out,
    s.active_qty,
    s.sell_in_sub,
    s.sell_in_account,
    count(am."Subsidiary") as account_mapping_matches
from io_diag_import_2025_after_current_mkt_filter s
left join bi_reporting.account_mapping am
    on am."Subsidiary" = s.sell_in_sub
   and am."OrgSales" = s.sell_in_account
group by
    s.row_key,
    s.in_out,
    s.active_qty,
    s.sell_in_sub,
    s.sell_in_account;

create temp table io_diag_import_2025_joined as
select
    s.*,
    am."Channel"::text as sell_in_channel,
    am."Country"::text as sell_in_country
from io_diag_import_2025_after_current_mkt_filter s
left join bi_reporting.account_mapping am
    on am."Subsidiary" = s.sell_in_sub
   and am."OrgSales" = s.sell_in_account;

create temp table io_diag_import_2025_fanout as
select
    row_key,
    in_out,
    max(active_qty) as active_qty,
    count(*) as rows_after_join
from io_diag_import_2025_joined
group by
    row_key,
    in_out
having count(*) > 1;

select
    'source_scope_by_inout_mkt_status' as check_name,
    mkt_status,
    in_out,
    count(*) as rows,
    sum(active_qty) as active_qty,
    sum(case when in_out = 'Inflow' then active_qty else 0 end) as total_inflow,
    sum(active_qty) as domestic_demand
from io_diag_import_2025_source
group by
    mkt_status,
    in_out
order by
    mkt_status,
    in_out;

select
    'current_vs_strict_mkt_filter' as check_name,
    'current_keeps_blank_mkt_name' as filter_variant,
    count(*) as rows,
    sum(active_qty) as active_qty,
    sum(case when in_out = 'Inflow' then active_qty else 0 end) as total_inflow,
    sum(active_qty) as domestic_demand
from io_diag_import_2025_after_current_mkt_filter
union all
select
    'current_vs_strict_mkt_filter' as check_name,
    'strict_drops_blank_mkt_name' as filter_variant,
    count(*) as rows,
    sum(active_qty) as active_qty,
    sum(case when in_out = 'Inflow' then active_qty else 0 end) as total_inflow,
    sum(active_qty) as domestic_demand
from io_diag_import_2025_after_strict_mkt_filter
order by
    filter_variant;

select
    'account_mapping_duplicate_keys_hit' as check_name,
    sell_in_sub,
    sell_in_account,
    count(*) as source_rows_hit,
    max(account_mapping_matches) as account_mapping_matches,
    sum(active_qty) as active_qty
from io_diag_import_2025_account_hits
where account_mapping_matches > 1
group by
    sell_in_sub,
    sell_in_account
order by
    active_qty desc,
    account_mapping_matches desc,
    sell_in_sub,
    sell_in_account;

select
    'account_join_rows_by_inout' as check_name,
    j.in_out,
    count(*) as rows_after_join,
    count(distinct j.row_key) as rows_before_join,
    count(*) - count(distinct j.row_key) as added_rows,
    sum(j.active_qty) as active_qty_after_join
from io_diag_import_2025_joined j
group by
    j.in_out
order by
    j.in_out;

select
    'account_join_fanout_by_inout' as check_name,
    in_out,
    count(*) as source_rows_with_fanout,
    sum(rows_after_join) as rows_after_join_for_fanned_rows,
    sum(rows_after_join - 1) as added_rows,
    sum(active_qty * (rows_after_join - 1)) as added_active_qty
from io_diag_import_2025_fanout
group by
    in_out
order by
    in_out;

select
    'joined_totals_current_step_logic' as check_name,
    in_out,
    count(*) as rows,
    sum(active_qty) as active_qty,
    sum(case when in_out = 'Inflow' then active_qty else 0 end) as total_inflow,
    sum(active_qty) as domestic_demand
from io_diag_import_2025_joined
group by
    in_out
order by
    in_out;

select
    'materialized_view_import_totals' as check_name,
    "In/Out" as in_out,
    count(*) as rows,
    sum("Active Qty") as active_qty,
    sum("Total Inflow") as total_inflow,
    sum("Domestic Demand") as domestic_demand
from bi_reporting.io_1_quantity_mv
where "Source Side" = 'import'
  and "Year" = '2025'
group by
    "In/Out"
order by
    "In/Out";
