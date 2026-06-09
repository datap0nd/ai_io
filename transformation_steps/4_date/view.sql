-- Step 4: Move the Month Map table into SQL.
--
-- Run only after Step 3 amount validation passes.
-- This produces a SQL-backed Month Map from the validated fact table range.

drop materialized view if exists bi_reporting.io_4_date_mv;

create materialized view bi_reporting.io_4_date_mv as
select
    to_char(gs.month_date, 'YYYYMM')::bigint as "Month",
    'Q' || extract(quarter from gs.month_date)::text as "Quarter",
    extract(year from gs.month_date)::bigint as "Year",
    case
        when extract(month from gs.month_date) <= 6 then 'H1'
        else 'H2'
    end as "Half",
    gs.month_date::date as "Date"
from (
    select
        date_trunc('month', min(to_date("Month"::text, 'YYYYMM')))::date as min_date,
        date_trunc('month', max(to_date("Month"::text, 'YYYYMM')))::date as max_date
    from bi_reporting.io_3_amount_mv
    where "Month" is not null
) bounds
cross join lateral generate_series(bounds.min_date, bounds.max_date, interval '1 month') as gs(month_date)
where bounds.min_date is not null
with data;

create unique index io_4_date_mv_month_idx
on bi_reporting.io_4_date_mv ("Month");

-- After source data changes, refresh with:
-- refresh materialized view bi_reporting.io_4_date_mv;
