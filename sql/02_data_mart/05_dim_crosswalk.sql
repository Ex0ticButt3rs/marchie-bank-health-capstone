-- One row per CFPB company name from crosswalk. Unmatched companies are valid rows with NULL fdic_certificate_number as
-- Power BI reports could need to filter on non-banks.
-- company_category distinguishes bank from non-bank for report's matched-share calculation.


BEGIN;

DROP TABLE IF EXISTS data_mart.dim_crosswalk CASCADE;
CREATE TABLE data_mart.dim_crosswalk (
    company_name            TEXT PRIMARY KEY,
    match_method            TEXT NOT NULL,
    company_category        TEXT NOT NULL,
    fdic_certificate_number INTEGER REFERENCES data_mart.dim_bank (fdic_certificate_number)
);

INSERT INTO data_mart.dim_crosswalk
SELECT company_name, match_method, company_category, fdic_certificate_number
FROM data_warehouse.crosswalk;

COMMIT;