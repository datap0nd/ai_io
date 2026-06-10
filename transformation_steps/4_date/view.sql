-- Step 4: Move the Month Map table into SQL.
--
-- Run only after Step 3 amount validation passes.
-- This reproduces the fixed Power BI Month Map range and labels:
-- 202301 through 202812, with year-prefixed Quarter and Half values.

drop materialized view if exists bi_reporting.io_4_date_mv;

create materialized view bi_reporting.io_4_date_mv as
select
    to_char(gs.month_date, 'YYYYMM')::bigint as "Month",
    to_char(gs.month_date, 'YYYY') || 'Q' || extract(quarter from gs.month_date)::int::text as "Quarter",
    extract(year from gs.month_date)::bigint as "Year",
    to_char(gs.month_date, 'YYYY') ||
        case
            when extract(month from gs.month_date) <= 6 then 'H1'
            else 'H2'
        end as "Half",
    gs.month_date::date as "Date"
from generate_series(date '2023-01-01', date '2028-12-01', interval '1 month') as gs(month_date)
with data;

create unique index io_4_date_mv_month_idx
on bi_reporting.io_4_date_mv ("Month");

-- After source data changes, refresh with:
-- refresh materialized view bi_reporting.io_4_date_mv;
