-- Date dimension at quarterly grain. Generated, not derived from any fact.
-- Covers 1934 Q1 through 2026 Q3 so that failures (earliest 1934-04-19, latest 2026-07-17) sit on same axis as
-- financials (2006 Q1 - 2026 Q2). Complaints uses dim_date_daily instead.


BEGIN;

DROP TABLE IF EXISTS data_mart.dim_date_quarterly CASCADE;
CREATE TABLE data_mart.dim_date_quarterly (
    quarter_end_date DATE PRIMARY KEY,
    report_year      INTEGER NOT NULL,
    report_quarter   INTEGER NOT NULL CHECK (report_quarter BETWEEN 1 AND 4),
    year_quarter     TEXT    NOT NULL,   -- '2023 Q3', for axis labels
    decade           INTEGER NOT NULL    -- 1930, 1940, etc.
);

INSERT INTO data_mart.dim_date_quarterly (quarter_end_date, report_year, report_quarter, year_quarter, decade)
SELECT
    (q.quarter_start + INTERVAL '3 months' - INTERVAL '1 day')::date AS quarter_end_date,
    EXTRACT(YEAR FROM  q.quarter_start + INTERVAL '3 months' - INTERVAL '1 day')::INTEGER,
    EXTRACT(QUARTER FROM q.quarter_start + INTERVAL '3 months' - INTERVAL '1 day')::INTEGER,
    EXTRACT(YEAR FROM q.quarter_start + INTERVAL '3 months' - INTERVAL '1 day')::TEXT || ' Q' ||
        EXTRACT(QUARTER FROM q.quarter_start + INTERVAL '3 months' - INTERVAL '1 day')::TEXT,
    (EXTRACT(YEAR FROM q.quarter_start + INTERVAL '3 months' - INTERVAL '1 day')::INTEGER / 10) * 10
-- generate_series on first of month values then subtract one day to avoid day of month drift issue
FROM (SELECT generate_series('1934-01-01'::date, '2026-07-01'::date, INTERVAL '3 months')::date AS quarter_start) q;

COMMIT;