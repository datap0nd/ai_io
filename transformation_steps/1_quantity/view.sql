-- Step 1: Quantity-only materialized view for Global_Inflow_Outflow.
--
-- Purpose:
-- Move the core Power BI quantity transformation logic into PostgreSQL.
-- This step intentionally excludes ASP, amount metrics, date hierarchy,
-- item enrichment, M-Tracker bridge logic, and device-generation filtering.
--
-- Materialized view created:
-- bi_reporting.io_1_quantity_mv
--
-- Source of truth:
-- - MENA_Export
-- - MENA_Import
-- - Global_Inflow_Outflow append and calculated quantity columns

drop materialized view if exists bi_reporting.io_1_quantity_mv;

create materialized view bi_reporting.io_1_quantity_mv as
select
    src.source_side as "Source Side",
    src.sell_in_region as "Sell-in Region",
    src.sell_in_sub as "Sell-in Sub",
    src.sell_in_ap1 as "Sell-in AP1",
    src.sell_in_account as "Sell-in Account",
    src.sell_out_region as "Sell-out Region",
    src.sell_out_sub as "Sell-out Sub",
    src.sell_out_country as "Sell-out Country",
    src.current_region as "Current Region",
    src.current_sub as "Current Sub",
    src.current_country as "Current Country",
    src.biz_sub as "Biz Sub",
    src.series as "Series",
    src.mkt_name as "MKT Name",
    src.memory as "Memory",
    src.storage as "Storage",
    src.item_code as "Item Code",
    src.month as "Month",
    src.year as "Year",
    src.year || src.item_code as "ItemID",
    null::text as "Grand total",
    null::numeric as "ASP",
    src.biz_grp as "Biz Grp",
    src.sell_in_channel as "Sell-in Channel",
    src.sell_in_country as "Sell-in Country",
    src.sku as "SKU",
    src.in_out as "In/Out",

    -- Region and Subsidiary reproduce the Power BI Global_Inflow_Outflow
    -- post-append logic.
    case
        when src.in_out in ('Domestic-E', 'Outflow') then src.sell_in_region
        when src.in_out in ('Domestic-I', 'Inflow') then src.current_region
        else null
    end as "Region",
    case
        when src.in_out in ('Domestic-E', 'Outflow') then src.sell_in_sub
        when src.in_out in ('Domestic-I', 'Inflow') then src.current_sub
        else null
    end as "Subsidiary",

    -- Across Sub is now a SQL column instead of a Power BI calculated column.
    case
        when src.sell_in_sub = src.sell_out_sub
         and src.sell_out_sub <> src.current_sub then '2nd Activation'
        when src.sell_in_sub <> src.sell_out_sub
         and src.sell_in_sub <> src.current_sub then 'CI'
        when src.sell_in_sub = src.current_sub then 'Domestic'
        else null
    end as "Across Sub",

    src.active_qty as "Active Qty",
    src.total_inflow as "Total Inflow",
    src.from_mena as "From MENA",
    src.from_non_mena as "From Non-MENA",
    src.total_outflow as "Total Outflow",
    src.to_mena_outflow as "To MENA Outflow",
    src.to_non_mena as "To Non-MENA",

    -- Shared quantity columns from the Power BI Global_Inflow_Outflow query.
    case
        when src.in_out in ('Domestic-E', 'Outflow') then src.active_qty
        else 0
    end as "S/O SCM",
    case
        when src.in_out in ('Domestic-I', 'Inflow') then src.active_qty
        else 0
    end as "Domestic Demand",
    case
        when src.in_out = 'Domestic-E' then src.active_qty
        else 0
    end as "S/O that Stays",

    src.second_activation_in as "2nd Activation In",
    src.second_activation_out as "2nd Activation Out",
    src.ci_in as "CI In",
    src.ci_out as "CI Out",

    -- Parallel S/O is retained as quantity only in Step 1.
    case
        when src.sell_in_region <> 'MIDDLE EAST' then coalesce(src.total_inflow, 0) + coalesce(src.total_outflow, 0)
        when src.current_region <> 'MIDDLE EAST'
         and src.sell_in_region = 'MIDDLE EAST' then src.total_outflow
        else src.total_inflow
    end as "Parallel S/O"
from (
    -- Export side mirrors Power BI MENA_Export.
    select
        'export'::text as source_side,
        e."Sell-in Region"::text as sell_in_region,
        e."Sell-in Sub"::text as sell_in_sub,
        e."Sell-in AP1"::text as sell_in_ap1,
        e."Sell-in Account"::text as sell_in_account,
        e."Sell-out Region"::text as sell_out_region,
        e."Sell-out Sub"::text as sell_out_sub,
        e."Sell-out Country"::text as sell_out_country,
        e."Current Region"::text as current_region,
        e."Current Sub"::text as current_sub,
        e."Current Country"::text as current_country,
        e."Biz Sub"::text as biz_sub,
        e."Series"::text as series,
        e."MKT Name"::text as mkt_name,
        e."Memory"::text as memory,
        e."Storage"::text as storage,
        e."Item Code"::text as item_code,
        nullif(replace(e."Sell-out Month"::text, ',', ''), '')::bigint as month,
        left(replace(e."Sell-out Month"::text, ',', ''), 4) as year,
        nullif(replace(e."Active"::text, ',', ''), '')::numeric as active_qty,
        case
            when e."Biz Sub" in ('A', 'S', 'Z', 'Others(SMART)') then 'SMART'
            when e."Biz Sub" = 'Tablet' then 'TABLET'
            else 'WEARABLE'
        end as biz_grp,
        case
            when e."Sell-in Sub" = e."Current Sub" then 'Domestic-E'
            else 'Outflow'
        end as in_out,
        am."Channel"::text as sell_in_channel,
        am."Country"::text as sell_in_country,
        case
            when e."Biz Sub" in ('Tablet') then e."MKT Name"::text || '-' || e."Memory"::text || '-' || e."Storage"::text
            when e."Biz Sub" in ('A', 'S', 'Z', 'Others(SMART)') then e."MKT Name"::text || '-' || e."Memory"::text || '-' || e."Storage"::text
            else e."MKT Name"::text
        end as sku,
        null::numeric as total_inflow,
        null::numeric as from_mena,
        null::numeric as from_non_mena,
        case
            when e."Sell-in Sub" <> e."Current Sub" then nullif(replace(e."Active"::text, ',', ''), '')::numeric
            else 0
        end as total_outflow,
        case
            when e."Sell-in Sub" <> e."Current Sub"
             and e."Current Region" = 'MIDDLE EAST' then nullif(replace(e."Active"::text, ',', ''), '')::numeric
            else 0
        end as to_mena_outflow,
        case
            when e."Sell-in Sub" <> e."Current Sub"
             and e."Current Region" <> 'MIDDLE EAST' then nullif(replace(e."Active"::text, ',', ''), '')::numeric
            else 0
        end as to_non_mena,
        null::numeric as second_activation_in,
        null::numeric as ci_in,
        case
            when e."Sell-in Sub" <> e."Current Sub"
             and e."Sell-in Sub" = e."Sell-out Sub" then nullif(replace(e."Active"::text, ',', ''), '')::numeric
            else 0
        end as second_activation_out,
        case
            when e."Sell-in Sub" <> e."Sell-out Sub"
             and e."Sell-in Sub" <> e."Current Sub" then nullif(replace(e."Active"::text, ',', ''), '')::numeric
            else 0
        end as ci_out
    from "Zahab"."ASAP Export_1st and 2nd Activation" e
    left join bi_reporting.account_mapping am
        on am."Subsidiary" = e."Sell-in Sub"
       and am."OrgSales" = e."Sell-in Account"
    where e."Sell-in Region" = 'MIDDLE EAST'

    union all

    -- Import side mirrors Power BI MENA_Import.
    select
        'import'::text as source_side,
        i."Sell-in Region"::text as sell_in_region,
        i."Sell-in Sub"::text as sell_in_sub,
        i."Sell-in AP1"::text as sell_in_ap1,
        i."Sell-in Account"::text as sell_in_account,
        i."Sell-out Region"::text as sell_out_region,
        i."Sell-out Sub"::text as sell_out_sub,
        i."Sell-out Country"::text as sell_out_country,
        i."Current Region"::text as current_region,
        i."Current Sub"::text as current_sub,
        i."Current Country"::text as current_country,
        i."Biz Sub"::text as biz_sub,
        i."Series"::text as series,
        i."MKT Name"::text as mkt_name,
        i."Memory"::text as memory,
        i."Storage"::text as storage,
        i."Item Code"::text as item_code,
        nullif(replace(i."Sell-out Month"::text, ',', ''), '')::bigint as month,
        left(replace(i."Sell-out Month"::text, ',', ''), 4) as year,
        nullif(replace(i."Active"::text, ',', ''), '')::numeric as active_qty,
        case
            when i."Biz Sub" in ('A', 'S', 'Z', 'Others(SMART)') then 'SMART'
            when i."Biz Sub" = 'Tablet' then 'TABLET'
            else 'WEARABLE'
        end as biz_grp,
        case
            when i."Sell-in Sub" = i."Current Sub" then 'Domestic-I'
            else 'Inflow'
        end as in_out,
        case
            when i."Sell-in Region" = 'MIDDLE EAST' then am."Channel"::text
            else 'Non-Domestic'
        end as sell_in_channel,
        case
            when i."Sell-in Region" = 'MIDDLE EAST' then am."Country"::text
            else 'Non-Domestic'
        end as sell_in_country,
        case
            when i."Biz Sub" in ('Tablet') then i."MKT Name"::text || '-' || i."Memory"::text || '-' || i."Storage"::text
            when i."Biz Sub" in ('A', 'S', 'Z', 'Others(SMART)') then i."MKT Name"::text || '-' || i."Memory"::text || '-' || i."Storage"::text
            else i."MKT Name"::text
        end as sku,
        case
            when i."Sell-in Sub" <> i."Current Sub" then nullif(replace(i."Active"::text, ',', ''), '')::numeric
            else 0
        end as total_inflow,
        case
            when i."Sell-in Sub" <> i."Current Sub"
             and i."Sell-in Region" = 'MIDDLE EAST' then nullif(replace(i."Active"::text, ',', ''), '')::numeric
            else 0
        end as from_mena,
        case
            when i."Sell-in Sub" <> i."Current Sub"
             and i."Sell-in Region" <> 'MIDDLE EAST' then nullif(replace(i."Active"::text, ',', ''), '')::numeric
            else 0
        end as from_non_mena,
        null::numeric as total_outflow,
        null::numeric as to_mena_outflow,
        null::numeric as to_non_mena,
        case
            when i."Sell-in Sub" <> i."Current Sub"
             and i."Sell-in Sub" = i."Sell-out Sub" then nullif(replace(i."Active"::text, ',', ''), '')::numeric
            else 0
        end as second_activation_in,
        case
            when i."Sell-in Sub" <> i."Sell-out Sub"
             and i."Sell-in Sub" <> i."Current Sub" then nullif(replace(i."Active"::text, ',', ''), '')::numeric
            else 0
        end as ci_in,
        null::numeric as second_activation_out,
        null::numeric as ci_out
    from "Zahab"."ASAP Import_1st and 2nd Activation" i
    left join bi_reporting.account_mapping am
        on am."Subsidiary" = i."Sell-in Sub"
       and am."OrgSales" = i."Sell-in Account"
    -- The Excel import baseline only contains MIDDLE EAST sell-in rows.
    -- The Zahab SQL table is broader, so enforce the same source scope here.
    where i."Sell-in Region" = 'MIDDLE EAST'
      and i."Current Region" = 'MIDDLE EAST'
) src
where (
    src.mkt_name is null
    or src.mkt_name not in ('Galaxy Z Fold Special Edition', 'W25', 'W25 Flip')
)
with data;

create index io_1_quantity_mv_month_idx
on bi_reporting.io_1_quantity_mv ("Month");

create index io_1_quantity_mv_itemid_idx
on bi_reporting.io_1_quantity_mv ("ItemID");

create index io_1_quantity_mv_inout_idx
on bi_reporting.io_1_quantity_mv ("In/Out");

-- After source data changes, refresh with:
-- refresh materialized view bi_reporting.io_1_quantity_mv;
