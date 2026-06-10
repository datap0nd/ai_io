-- Step 3: Add amount columns.
--
-- Run only after Step 2 ASP validation passes.
-- This preserves the Step 2 quantity and ASP columns, then adds the amount
-- columns that Power BI previously calculated as quantity multiplied by ASP.

drop materialized view if exists bi_reporting.io_3_amount_mv;

create materialized view bi_reporting.io_3_amount_mv as
select
    q."Source Side",
    q."Sell-in Region",
    q."Sell-in Sub",
    q."Sell-in AP1",
    q."Sell-in Account",
    q."Sell-out Region",
    q."Sell-out Sub",
    q."Sell-out Country",
    q."Current Region",
    q."Current Sub",
    q."Current Country",
    q."Biz Sub",
    q."Series",
    q."MKT Name",
    q."Memory",
    q."Storage",
    q."Item Code",
    q."Month",
    q."Year",
    q."ItemID",
    q."Grand total",
    q."ASP",
    q."Biz Grp",
    q."Sell-in Channel",
    q."Sell-in Country",
    q."SKU",
    q."In/Out",
    q."Region",
    q."Subsidiary",
    q."Across Sub",
    q."Active Qty",
    case
        when q."ASP" is null then null
        else q."ASP" * q."Active Qty"
    end as "S/O Amt",
    q."Total Inflow",
    q."From MENA",
    q."From Non-MENA",
    q."Total Outflow",
    q."To MENA Outflow",
    q."To Non-MENA",
    q."S/O SCM",
    q."Domestic Demand",
    q."S/O that Stays",
    q."Domestic Demand" * q."ASP" as "Domestic Demand Amt",
    q."From MENA" * q."ASP" as "From MENA Amt",
    q."From Non-MENA" * q."ASP" as "From Non-MENA Amt",
    q."S/O SCM" * q."ASP" as "S/O SCM Amt",
    q."S/O that Stays" * q."ASP" as "S/O that Stays Amt",
    q."To MENA Outflow" * q."ASP" as "To MENA Outflow Amt",
    q."To Non-MENA" * q."ASP" as "To Non-MENA Amt",
    q."Total Inflow" * q."ASP" as "Total Inflow Amt",
    q."Total Outflow" * q."ASP" as "Total Outflow Amt",
    q."2nd Activation In",
    q."2nd Activation Out",
    q."CI In",
    q."CI Out",
    q."2nd Activation In" * q."ASP" as "2nd Activation In Amt",
    q."2nd Activation Out" * q."ASP" as "2nd Activation Out Amt",
    q."CI In" * q."ASP" as "CI In Amt",
    q."CI Out" * q."ASP" as "CI Out Amt",
    q."Parallel S/O",
    case
        when q."Sell-in Region" <> 'MIDDLE EAST'
         and q."Total Inflow" * q."ASP" is null
         and q."Total Outflow" * q."ASP" is null then null
        when q."Sell-in Region" <> 'MIDDLE EAST' then coalesce(q."Total Inflow" * q."ASP", 0) + coalesce(q."Total Outflow" * q."ASP", 0)
        when q."Current Region" <> 'MIDDLE EAST'
         and q."Sell-in Region" = 'MIDDLE EAST' then q."Total Outflow" * q."ASP"
        else q."Total Inflow" * q."ASP"
    end as "Parallel S/O Amt"
from bi_reporting.io_2_asp_mv q
with data;

create index io_3_amount_mv_month_idx
on bi_reporting.io_3_amount_mv ("Month");

create index io_3_amount_mv_itemid_idx
on bi_reporting.io_3_amount_mv ("ItemID");

create index io_3_amount_mv_inout_idx
on bi_reporting.io_3_amount_mv ("In/Out");

-- After source data changes, refresh with:
-- refresh materialized view bi_reporting.io_3_amount_mv;
