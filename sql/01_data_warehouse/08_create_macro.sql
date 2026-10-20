-- One row per quarter-end, 2006 Q1 through 2026 Q2.
-- Aligned in clean by taking last observation on or before quarter end. FRED series with no observation before a quarter
-- remains NULL instead of being filled forward because don't want to invent a value publisher did not provide.


BEGIN;

DROP TABLE IF EXISTS data_warehouse.macro_quarterly CASCADE;
CREATE TABLE data_warehouse.macro_quarterly (
    quarter_end_date                  DATE    PRIMARY KEY,
    federal_funds_rate_percent        NUMERIC,
    unemployment_rate_percent         NUMERIC,
    thirty_year_mortgage_rate_percent NUMERIC,
    ten_year_treasury_yield_percent   NUMERIC
);

INSERT INTO data_warehouse.macro_quarterly
SELECT quarter_end_date, federal_funds_rate_percent, unemployment_rate_percent, thirty_year_mortgage_rate_percent,
    ten_year_treasury_yield_percent
FROM clean.macro_quarterly;

COMMIT;