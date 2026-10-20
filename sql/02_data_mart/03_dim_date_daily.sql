-- Date dimension at daily grain. Generated, not derived from any fact.
-- Covers 2019-01-01 through 2026-06-30 as is CFPB complaint window. Only fact_complaints joins this dimension as failures
-- and financials join dim_date_quarterly instead.


BEGIN;

DROP TABLE IF EXISTS data_mart.dim_date_daily CASCADE;
CREATE TABLE data_mart.dim_date_daily (
    daily_date          DATE    PRIMARY KEY,
    quarter_end_date    DATE    NOT NULL REFERENCES data_mart.dim_date_quarterly (quarter_end_date),
    report_year         INTEGER NOT NULL,
    report_month        INTEGER NOT NULL CHECK (report_month BETWEEN 1 AND 12),
    year_month          TEXT    NOT NULL,   -- '2023-07', for axis labels
    decade              INTEGER NOT NULL    -- 1930, 1940, etc.
);

INSERT INTO data_mart.dim_date_daily (daily_date, quarter_end_date, report_year, report_month, year_month, decade)
SELECT
    d.daily_date,
    (DATE_TRUNC('quarter', d.daily_date)::date + INTERVAL '3 months' - INTERVAL '1 day')::date AS quarter_end_date,
    EXTRACT(YEAR FROM d.daily_date)::INTEGER,
    EXTRACT(MONTH FROM d.daily_date)::INTEGER,
    TO_CHAR(d.daily_date, 'YYYY-MM'),
    (EXTRACT(YEAR FROM d.daily_date)::INTEGER / 10) * 10
FROM (SELECT generate_series('2019-01-01'::date, '2026-06-30'::date, INTERVAL '1 day')::date AS daily_date) d;

COMMIT;