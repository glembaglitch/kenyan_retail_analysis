-- create schema and set search_path
create schema if not exists sql_analysis;

set search_path to sql_analysis;

-- create tables and import data
drop table if exists raw_shop, raw_cpi, raw_inflation, raw_holidays, raw_population cascade;

create table raw_shop (
    "InvoiceNo" text, 
    "CustomerID" text, 
    "Product" text, 
    "Quantity" text,
    "UnitPrice" text, 
    "TotalPrice" text, 
    "InvoiceDate" text,
    "Location" text, 
    "CustomerType" text
);

create table raw_cpi (
    "Period" text, 
    "Series" text, 
    "Value" text, 
    "Monthly Change (%)" text,
    "Annual Change (%)" text, 
    "Category" text, 
    "Region" text, 
    "Data Type" text
);

create table raw_inflation (LIKE raw_cpi);

create table raw_holidays (
    "Year" text, 
    "Holiday Name" text, 
    "Date" text, 
    "Day of Week" text, 
    "Type" text
);

create table raw_population (
    "Reference Area (KE)" text, 
    "Census Indicators (POP_TOT)" text, 
    "Sex (M)" text,
    "Employment status (_T)" text, 
    "Time period (2019)" text, 
    "Observation" text,
    "Observation Status" text, 
    "Unit of measure" text, 
    "Unit Multipler" text,
    "Time  Period Comment" text, 
    "Time Series Comment" text, 
    "Dataset Comment" text,
    "Source" text
);

-- rename columns after importation
do $$
declare
    r record;
    newname text;
begin
    for r in
        select table_name, column_name
        from information_schema.columns
        where table_schema = 'sql_analysis'
          and table_name in ('raw_shop','raw_cpi','raw_inflation','raw_holidays','raw_population')
    loop
        -- "Monthly Change (%)" -> monthly_change ; "CustomerID" -> customerid ; etc.
        newname := trim(both '_' from lower(regexp_replace(r.column_name, '[^a-zA-Z0-9]+', '_', 'g')));

        newname := case newname
            -- shop
            when 'invoiceno'    then 'invoice_no'
            when 'customerid'   then 'customer_id'
            when 'unitprice'    then 'unit_price'
            when 'totalprice'   then 'total_price'
            when 'invoicedate'  then 'invoice_date'
            when 'customertype' then 'customer_type'
            -- cpi / inflation
            when 'monthly_change' then 'monthly_change_pct'
            when 'annual_change'  THEN 'annual_change_pct'
            -- population
            when 'reference_area_ke'            then 'reference_area'
            when 'census_indicators_pop_tot'    then 'census_indicator'
            when 'sex_m'                        then 'sex'
            when 'employment_status_t'          then 'employment_status'
            when 'time_period_2019'             then 'time_period'
            when 'unit_multipler'               then 'unit_multiplier'
            else newname
        end;
        
        -- make every raw column text so cleaning can type it
        execute format('ALTER TABLE sql_analysis.%I ALTER COLUMN %I TYPE text USING %I::text',
                       r.table_name, r.column_name, r.column_name);

        IF newname <> r.column_name then
            execute format('ALTER TABLE sql_analysis.%I RENAME COLUMN %I TO %I',
                           r.table_name, r.column_name, newname);
        end if;
    end loop;
end $$;

-- check the resulting column names
select table_name, string_agg(column_name, ', ' order by ordinal_position) as columns
from information_schema.columns
where table_schema = 'sql_analysis' and table_name like 'raw\_%'
group by table_name order by table_name;

-- data cleaning
--- profile issues
select
    count(*) as total_rows,
    count(*) filter (where nullif(trim(customer_id),'') is null) as missing_customer,
    count(*) filter (where quantity::numeric <= 0) as non_positive_qty,
    count(*) filter (where unit_price::numeric <= 0) as non_positive_price,
    count(*) - count(distinct (invoice_no, product, customer_id)) as duplicate_lines
from raw_shop;


CREATE OR REPLACE FUNCTION sql_analysis.parse_ts(t text)
RETURNS timestamp LANGUAGE sql IMMUTABLE AS $$
SELECT CASE
    WHEN t IS NULL OR btrim(t) = ''                       THEN NULL
    WHEN btrim(t) ~ '^\d{4}-\d{1,2}-\d{1,2}'              THEN btrim(t)::timestamp
    WHEN btrim(t) ~ '^\d{1,2}/\d{1,2}/\d{4}' THEN
        CASE WHEN split_part(btrim(t), '/', 1)::int > 12
             THEN to_timestamp(btrim(t), 'DD/MM/YYYY HH24:MI:SS')::timestamp
             ELSE to_timestamp(btrim(t), 'MM/DD/YYYY HH24:MI:SS')::timestamp
        END
END
$$;

---shop transactions
create table shop_clean as
with typed as (
    select
        upper(trim(invoice_no)) as invoice_no,
        upper(trim(customer_id)) as customer_id,
        initcap(trim(product)) as product,
        nullif(trim(quantity),'')::numeric::int as quantity,
        nullif(trim(unit_price),'')::numeric(12,2) as unit_price,
        sql_analysis.parse_ts(invoice_date) as invoice_ts,
        initcap(trim(location)) as location,
        initcap(trim(customer_type)) as customer_type
    from sql_analysis.raw_shop
),
filtered as (
    select * from typed
    where customer_id is not null and customer_id <> ''
      and invoice_no is not null and
      and quantity   > 0
      and unit_price > 0
      and invoice_ts is not null
),
dedup as (
    select distinct on (invoice_no, product, customer_id, invoice_ts) *
    from filtered
    order by invoice_no, product, customer_id, invoice_ts
)
select
    row_number() over () as line_id,
    invoice_no, customer_id, product, quantity, unit_price,
    round(quantity * unit_price, 2) as total_price,
    invoice_ts,
    invoice_ts::date as invoice_date,
    date_trunc('month', invoice_ts)::date as invoice_month,
    location, customer_type
from dedup;

alter table sql_analysis.shop_clean add primary key (line_id);

---- sanity check
select count(*) as rows_kept,
       min(invoice_date) as first_date,
       max(invoice_date) as last_date,
       count(distinct customer_id) as customers,
       count(distinct invoice_no)  as invoices
from sql_analysis.shop_clean;

--- cpi, inflation
select 'cpi' t, period, count(*) from sql_analysis.raw_cpi group by period order by 2 limit 5;

create table cpi_clean as
select
    date_trunc('month', parse_ts(period))::date as period_month,
    trim(series) as series,
    nullif(value,'')::numeric as value,
    nullif(monthly_change_pct,'')::numeric as monthly_change_pct,
    nullif(annual_change_pct,'')::numeric  as annual_change_pct,
    trim(category) as category, 
    trim(region) as region, 
    trim(data_type) AS data_type
from raw_cpi
where parse_ts(period) is not null;

create table inflation_clean as
select 
    date_trunc('month', parse_ts(period))::date as period_month,
    trim(series) as series,
    nullif(value,'')::numeric as value,
    nullif(monthly_change_pct,'')::numeric as monthly_change_pct,
    nullif(annual_change_pct,'')::numeric  as annual_change_pct,
    trim(category) as category,
    trim(region) as region, 
    trim(data_type) AS data_type
from raw_inflation
where parse_ts(period) is not null;

--- holidays
select 'holidays' t, date, holiday_name from sql_analysis.raw_holidays limit 5;

create table holidays_clean as
select 
    distinct nullif(year,'')::numeric::int as year,
    trim(holiday_name) as holiday_name,
    parse_ts(date)::date as holiday_date,
    trim(day_of_week) AS day_of_week,
    trim(type) as holiday_type
from raw_holidays
where parse_ts(date) is not null;

--- population
create table population_clean as
select trim(reference_area) as area, trim(census_indicator) as indicator,
       trim(sex) as sex, trim(employment_status) as employment_status,
       nullif(time_period,'')::numeric::int as census_year,
       nullif(observation,'')::numeric::bigint as population,
       trim(unit_of_measure) as unit
from raw_population
where nullif(observation,'') is not null;

--- row counts vs. raw (cpi/inflation/holidays should be close to raw; check any big drop)
select 'cpi' t, (select count(*) from raw_cpi) raw, (select count(*) from cpi_clean) clean
union all select 'inflation', (select count(*) from raw_inflation), (select count(*) from inflation_clean)
union all select 'holidays',  (select count(*) from raw_holidays),  (select count(*) from holidays_clean)
union all select 'population',(select count(*) from raw_population),(select count(*) from population_clean)
union all select 'shop',(select count(*) from raw_shop),(select count(*) from shop_clean);

-- Total-population-by-area view (all sexes/employment totals 
create view v_population_area as
select area, census_year, sum(population) as population
from population_clean
group by area, census_year;

-- AGGREGATIONS(core busssiness questions)
--- 1. Overall KPIs
select
    count(distinct invoice_no) as orders,
    count(distinct customer_id) as customers,
    sum(total_price) as revenue,
    round(sum(total_price) / count(distinct invoice_no), 2) as avg_order_value,
    round(sum(quantity)::numeric / count(distinct invoice_no), 2) as units_per_order
from shop_clean;

--- 2. Monthly revenue, orders, customers
select
    invoice_month,
    sum(total_price) as revenue,
    count(distinct invoice_no) as orders,
    count(distinct customer_id) as active_customers
from shop_clean
group by invoice_month
order by invoice_month;

--- 3. Top 10 products by revenue (with share of total)
select
    product,
    sum(quantity) as units_sold,
    sum(total_price) as revenue,
    round(100 * sum(total_price) / sum(sum(total_price)) over (), 2) as pct_of_revenue
from shop_clean
group by product
order by revenue desc
limit 10;

--- 4. Revenue by location
select location,
       count(distinct customer_id) as customers,
       count(distinct invoice_no) as orders,
       sum(total_price) as revenue,
       round(avg(total_price),2) as avg_line_value
from shop_clean
group by location
order by revenue desc;

--- 5. Customer type comparison
select customer_type,
       count(distinct customer_id) as customers,
       sum(total_price) as revenue,
       round(sum(total_price)/count(distinct customer_id),2) as revenue_per_customer,
       round(sum(total_price)/count(distinct invoice_no),2) as aov
from shop_clean
group by customer_type
order by revenue desc;

--- 6. Day-of-week and hour-of-day demand
select to_char(invoice_ts,'Dy') as dow, extract(isodow from invoice_ts) as dow_num,
       count(distinct invoice_no) as orders, sum(total_price) as revenue
from shop_clean
group by 1,2 order by 2;

select extract(hour from invoice_ts)::int as hour_of_day,
       count(distinct invoice_no) as orders, sum(total_price) as revenue
from shop_clean
group by 1 order by 1;

--- 7. Product x location revenue matrix with subtotals
select coalesce(location,'ALL LOCATIONS') as location,
       coalesce(product,'ALL PRODUCTS')   as product,
       sum(total_price) as revenue
from shop_clean
group by rollup (location, product)
order by location, revenue desc;

--- 8. Repeat vs one-time customers
with c as (
    select customer_id, count(distinct invoice_no) as orders
    from shop_clean group by customer_id
)
select case when orders = 1 then 'One-time' else 'Repeat' end as customer_group,
       count(*) as customers,
       round(100.0*count(*)/sum(count(*)) over (),1) as pct
from c group by 1;

-- JOINS
-- Reusable CPI/inflation monthly series (headline index)
create or replace view sql_analysis.v_cpi_monthly as
select period_month,
       value as cpi_value,
       monthly_change_pct as cpi_mom_pct,
       annual_change_pct as cpi_yoy_pct
from sql_analysis.cpi_clean
where category = 'Overall CPI';

select category, series, min(period_month), max(period_month), count(*)
from inflation_clean group by 1,2 order by 5 desc;

create or replace view sql_analysis.v_inflation_monthly as
select period_month,
       annual_change_pct as inflation_yoy_pct,
       monthly_change_pct as inflation_mom_pct
from sql_analysis.inflation_clean;

--- Join_1: Monthly revenue vs CPI and inflation (LEFT JOIN keeps all sales months)
select
    m.invoice_month,
    m.revenue,
    m.orders,
    c.cpi_value,
    c.cpi_yoy_pct,
    i.inflation_yoy_pct,
    round(m.revenue / nullif(c.cpi_value,0) * 100, 2) as real_revenue_cpi_adj
from (
    select invoice_month, sum(total_price) as revenue, count(distinct invoice_no) as orders
    from shop_clean group by invoice_month
) m
left join v_cpi_monthly c on c.period_month = m.invoice_month
left join v_inflation_monthly i on i.period_month = m.invoice_month
order by m.invoice_month;

--- Join_2: Holiday vs non-holiday daily sales
with daily as (
    select invoice_date, sum(total_price) as revenue, count(distinct invoice_no) as orders
    from shop_clean group by invoice_date
)
select
    (h.holiday_date is not null) as is_holiday,
    count(*) as days,
    round(avg(d.revenue),2) as avg_daily_revenue,
    round(avg(d.orders),2) as avg_daily_orders
from daily d
left join holidays_clean h on h.holiday_date = d.invoice_date
group by 1;

--- Join_3: Sales by individual holiday, with the 3 days leading up to it
select h.holiday_name, h.year,
       sum(s.total_price) filter (where s.invoice_date =  h.holiday_date) as on_day,
       sum(s.total_price) filter (where s.invoice_date between h.holiday_date-3 and h.holiday_date-1) as pre_3_days
from holidays_clean h
join shop_clean s on s.invoice_date between h.holiday_date-3 and h.holiday_date
group by h.holiday_name, h.year, h.holiday_date
order by h.holiday_date;

--- Join_4: Revenue per capita by location (name match to population areas)
select
    s.location,
    sum(s.total_price) as revenue,
    p.population,
    round(sum(s.total_price) / nullif(p.population,0), 4) as revenue_per_capita
from shop_clean s
join v_population_area p on lower(p.area) = lower(s.location)
group by s.location, p.population
order by revenue_per_capita desc;

-- Check which shop locations fail to match population areas
select distinct s.location
from shop_clean s
left join v_population_area p on lower(p.area) = lower(s.location)
where p.area is null;

--- Join_5: Self-join: product pairs bought in the same invoice (market basket)
select a.product as product_a, b.product as product_b, count(*) as times_together
from shop_clean a
join shop_clean b on a.invoice_no = b.invoice_no and a.product < b.product
group by 1,2
order by times_together DESC
limit 20; 

--- Join_6: Products bought by the same customer (any time in 2023)
with cp as (
    select distinct customer_id, product from sql_analysis.shop_clean
)
select a.product as product_a, b.product as product_b,
       count(*) as customers_buying_both
from cp a
join cp b on a.customer_id = b.customer_id and a.product < b.product
group by 1,2
order by customers_buying_both DESC
limit 20;

--- Join_7: Pairs bought by the same customer on the same day (treating that as one shopping trip):
with trip as (
    select distinct customer_id, invoice_date, product from shop_clean
)
select a.product as product_a, b.product as product_b, count(*) as trips_together
from trip a
join trip b on a.customer_id = b.customer_id
           and a.invoice_date = b.invoice_date
           and a.product < b.product
group by 1,2
order by trips_together desc
limit 20;

-- WINDOW FUNCTIONS
--- W_1: Month-over-month revenue growth + running total
with m as (
    select invoice_month, sum(total_price) as revenue
    from shop_clean group by invoice_month
)
select invoice_month, revenue,
       lag(revenue) over (order by invoice_month) as prev_month,
       round(100*(revenue - lag(revenue) over (order by invoice_month))
             / nullif(lag(revenue) over (order by invoice_month),0), 2) as mom_growth_pct,
       sum(revenue) over (order by invoice_month) as cumulative_revenue,
       round(avg(revenue) over (order by invoice_month
             rows between 2 preceding and current row), 2) as moving_avg_3m
from m order by invoice_month;

--- W_2: Top 3 products per location (RANK within partition)
select * from (
    select location, product, sum(total_price) as revenue,
           dense_rank() over (partition by location order by sum(total_price) desc) as rnk
    from shop_clean group by location, product
) t where rnk <= 3
order by location, rnk;

--- W_3: Customer order sequence: days between orders
with orders as (
    select customer_id, invoice_no, min(invoice_date) as order_date, sum(total_price) as order_value
    from shop_clean group by customer_id, invoice_no
)
select customer_id, invoice_no, order_date, order_value,
       row_number() over w as order_number,
       order_date - lag(order_date) over w as days_since_prev_order,
       sum(order_value) over (partition by customer_id order by order_date, invoice_no) as customer_lifetime_value
from orders
window w as (partition by customer_id order by order_date, invoice_no)
order by customer_id, order_number;

--- W_4: Average repurchase interval overall
with o as (
    select customer_id, invoice_no, min(invoice_date) as d from shop_clean group by 1,2
), g as (
    select d - lag(d) over (partition by customer_id order by d, invoice_no) as gap from o
)
select round(avg(gap),1) as avg_days_between_orders,
       percentile_cont(0.5) within group (order by gap) as median_days
from g where gap is not null;

-- W_5: Pareto: customers ranked by revenue with cumulative share
with c as (
    select customer_id, sum(total_price) as revenue from shop_clean group by 1
)
select customer_id, revenue,
       rank() over (order by revenue desc) as rnk,
       round(100*sum(revenue) over (order by revenue desc) / sum(revenue) over (), 2) as cum_pct_revenue,
       ntile(10) over (order BY revenue desc) as decile
from c order by revenue desc;

-- W_6: Share of location revenue within each month
select invoice_month, location, sum(total_price) as revenue,
       round(100*sum(total_price)/sum(sum(total_price)) over (partition by invoice_month),2) as pct_of_month
from shop_clean group by invoice_month, location
order by invoice_month, revenue desc;

-- W_7: Year-over-year using lag(12) on monthly series
with m as (select invoice_month, sum(total_price) as revenue from shop_clean group by 1)
select invoice_month, revenue,
       lag(revenue,12) over (order by invoice_month) as same_month_last_year,
       round(100*(revenue/nullif(lag(revenue,12) over (order by invoice_month),0) - 1),2) as yoy_pct
from m order by invoice_month;

-- CUSTOMER COHORTS / RETENTION
create view v_cohort_activity as
with first_purchase as (
    select customer_id, min(invoice_month) as cohort_month
    from shop_clean group by customer_id
),
activity as (
    select distinct customer_id, invoice_month from shop_clean
)
select
    f.cohort_month,
    a.customer_id,
    a.invoice_month,
    ((extract(year from a.invoice_month) - extract(year from f.cohort_month)) * 12
     + (extract(month from a.invoice_month) - extract(month from f.cohort_month)))::int as month_index
from first_purchase f
join activity a using (customer_id);

--- C1: Cohort sizes and retention counts (long form)
select cohort_month, month_index,
       count(distinct customer_id) as active_customers
from v_cohort_activity
group by cohort_month, month_index
order by cohort_month, month_index;

--- C2: Retention rate % (long form)
with c as (
    select cohort_month, month_index, count(distinct customer_id) as n
    from v_cohort_activity group by 1,2
)
select cohort_month, month_index, n,
       round(100.0 * n / first_value(n) over (partition by cohort_month order by month_index), 1) as retention_pct
from c order by cohort_month, month_index;

-- C3: Retention heatmap (pivot, months 0-6)
select cohort_month,
       count(distinct customer_id) filter (where month_index = 0) as m0,
       round(100.0*count(distinct customer_id) filter (where month_index = 1)
             / nullif(count(distinct customer_id) filter (where month_index = 0),0),1) as m1_pct,
       round(100.0*count(distinct customer_id) filter (where month_index = 2)
             / nullif(count(distinct customer_id) filter (where month_index = 0),0),1) as m2_pct,
       round(100.0*count(distinct customer_id) filter (where month_index = 3)
             / nullif(count(distinct customer_id) filter (where month_index = 0),0),1) as m3_pct,
       round(100.0*count(distinct customer_id) filter (where month_index = 4)
             / nullif(count(distinct customer_id) filter (where month_index = 0),0),1) as m4_pct,
       round(100.0*count(distinct customer_id) filter (where month_index = 5)
             / nullif(count(distinct customer_id) filter (where month_index = 0),0),1) as m5_pct,
       round(100.0*count(distinct customer_id) filter (where month_index = 6)
             / nullif(count(distinct customer_id) filter (where month_index = 0),0),1) as m6_pct
from v_cohort_activity
group by cohort_month
order by cohort_month;

--- C4: Cohort revenue per customer by month index
with first_purchase as (
    select customer_id, min(invoice_month) as cohort_month from shop_clean group by 1
)
select f.cohort_month,
       ((extract(year from s.invoice_month)-extract(year from f.cohort_month))*12
        + extract(month from s.invoice_month)-extract(month from f.cohort_month))::int as month_index,
       sum(s.total_price) as revenue,
       count(distinct s.customer_id) as customers,
       round(sum(s.total_price)/count(distinct s.customer_id),2) AS revenue_per_active_customer
from shop_clean s join first_purchase f using (customer_id)
group by 1,2 order by 1,2;

--- C5: New vs returning customers per month
with first_purchase as (
    select customer_id, min(invoice_month) as cohort_month from shop_clean group by 1
)
select s.invoice_month,
       count(distinct s.customer_id) filter (where s.invoice_month = f.cohort_month) as new_customers,
       count(distinct s.customer_id) filter (where s.invoice_month > f.cohort_month) as returning_customers
from shop_clean s join first_purchase f using (customer_id)
group by 1 order by 1;

-- RFM SEGMENTATION
create table rfm_segments as
with snapshot as (
    select (max(invoice_date) + 1) as snap_date from shop_clean
),
base as (
    select
        s.customer_id,
        (select snap_date from snapshot) - max(s.invoice_date) as recency_days,
        count(DISTINCT s.invoice_no) as frequency,
        sum(s.total_price) as monetary
    from shop_clean s
    group by s.customer_id
),
scored as (
    select *,
        ntile(5) over (order by recency_days desc)  as r_score, 
        ntile(5) over (order by frequency asc) as f_score,
        ntile(5) over (order by monetary asc) as m_score
    from base
)
select
    customer_id, recency_days, frequency, round(monetary,2) as monetary,
    r_score, f_score, m_score,
    (r_score::text || f_score::text || m_score::text) as rfm_code,
    (r_score + f_score + m_score) as rfm_total,
    case
        when r_score >= 4 and f_score >= 4 and m_score >= 4 then 'Champions'
        when r_score >= 3 and f_score >= 4 then 'Loyal Customers'
        when r_score >= 4 and f_score BETWEEN 2 and 3 then 'Potential Loyalists'
        when r_score = 5  and f_score = 1 then 'New Customers'
        when r_score = 4  and f_score = 1 then 'Promising'
        when r_score = 3  and f_score BETWEEN 2 and 3 then 'Needs Attention'
        when r_score = 3  and f_score <= 1 then 'About To Sleep'
        when r_score <= 2 and f_score >= 4 then 'Cannot Lose Them'
        when r_score <= 2 and f_score BETWEEN 2 and 3 then 'At Risk'
        when r_score <= 2 and f_score <= 1 then 'Hibernating / Lost'
        ELSE 'Other'
    end as segment
from scored;

--- R1: Segment summary
select segment,
       count(*) as customers,
       round(100.0*count(*)/sum(count(*)) over (),1) as pct_customers,
       round(sum(monetary),2) as revenue,
       round(100.0*sum(monetary)/sum(sum(monetary)) over (),1) as pct_revenue,
       round(avg(recency_days),1) as avg_recency_days,
       round(avg(frequency),2) as avg_frequency,
       round(avg(monetary),2) as avg_monetary
from rfm_segments
group by segment
order by revenue desc;

--- R2: Segment by customer type and location
select r.segment, s.customer_type, count(distinct r.customer_id) as customers
from rfm_segments r
join (select distinct customer_id, customer_type from shop_clean) s using (customer_id)
group by 1,2 order by 1,3 desc;

-- R3: Top 20 Champions to reward
select * from rfm_segments where segment = 'Champions'
order by monetary desc limit 20;

-- R4: At-risk customers worth winning back (high spend, gone quiet)
select * from rfm_segments
where segment in ('At Risk','Cannot Lose Them')
order by monetary desc limit 50;

-- INDEXES AND REPORTING VIEWS
create index idx_shop_customer on shop_clean (customer_id);
create index idx_shop_invoice on shop_clean (invoice_no);
create index idx_shop_date on shop_clean (invoice_date);
create index idx_shop_month on shop_clean (invoice_month);
create index idx_hol_date on holidays_clean (holiday_date);
create index idx_cpi_month on cpi_clean (period_month);
create index idx_infl_month on inflation_clean (period_month);

-- One wide view for BI tools (Power BI / Tableau / Metabase)
create or replace view v_sales_enriched as
select s.*,
       (h.holiday_date is not null) as is_holiday,
       h.holiday_name,
       c.cpi_value, c.cpi_yoy_pct,
       i.inflation_yoy_pct,
       r.segment as rfm_segment
from shop_clean s
left join holidays_clean        h on h.holiday_date = s.invoice_date
left join v_cpi_monthly         c on c.period_month = s.invoice_month
left join v_inflation_monthly   i on i.period_month = s.invoice_month
left join rfm_segments          r on r.customer_id  = s.customer_id;

