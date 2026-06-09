-- Step 2: Add ASP to the validated quantity view.
--
-- Run only after Step 1 quantity validation passes.
-- This keeps row count and quantity columns unchanged, then fills ASP using
-- the same fallback shape as the Power BI model:
-- series ASP first, global ASP fallback when series ASP is missing, too high,
-- or non-positive.

drop materialized view if exists bi_reporting.io_2_asp_mv;

create materialized view bi_reporting.io_2_asp_mv as
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
    case
        when sa.series_asp is null then ga.global_asp
        when sa.series_asp > 1600 then ga.global_asp
        when sa.series_asp <= 0 then ga.global_asp
        else sa.series_asp
    end as "ASP",
    q."Biz Grp",
    q."Sell-in Channel",
    q."Sell-in Country",
    q."SKU",
    q."In/Out",
    q."Region",
    q."Subsidiary",
    q."Across Sub",
    q."Active Qty",
    q."Total Inflow",
    q."From MENA",
    q."From Non-MENA",
    q."Total Outflow",
    q."To MENA Outflow",
    q."To Non-MENA",
    q."S/O SCM",
    q."Domestic Demand",
    q."S/O that Stays",
    q."2nd Activation In",
    q."2nd Activation Out",
    q."CI In",
    q."CI Out",
    q."Parallel S/O"
from bi_reporting.io_1_quantity_mv q
left join (
    select
        series,
        category,
        amt / nullif(qty, 0) as series_asp
    from bi_reporting.series_asp_mv
) sa
    on sa.series = q."Series"
   and sa.category = q."Year"
left join (
    select
        "Biz Group"::text as biz_grp,
        "Category"::text as category,
        avg(nullif(replace("Total"::text, ',', ''), '')::numeric) as global_asp
    from "Zahab"."Sell-out Biz Plan Global_ASP"
    where "Category" <> 'DELTA'
    group by
        "Biz Group",
        "Category"
) ga
    on ga.biz_grp = q."Biz Grp"
   and ga.category = q."Year"
with data;

create index io_2_asp_mv_month_idx
on bi_reporting.io_2_asp_mv ("Month");

create index io_2_asp_mv_itemid_idx
on bi_reporting.io_2_asp_mv ("ItemID");

create index io_2_asp_mv_inout_idx
on bi_reporting.io_2_asp_mv ("In/Out");

-- After source data changes, refresh with:
-- refresh materialized view bi_reporting.io_2_asp_mv;
