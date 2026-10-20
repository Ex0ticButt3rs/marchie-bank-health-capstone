-- One row per failure event since 1934. fdic_certificate_number is nullable and has no FK to dim_bank: 488 rows carry
-- no CERT and some pre-2000 CERTs are not in institutions json file. Column stays for joins where it works.
-- failure_date FKs to dim_date at quarter grain via a derived quarter-end.

-- fdic_failures.csv	One row per failure or assistance transaction since 1934


BEGIN;

DROP TABLE IF EXISTS data_mart.fact_failures CASCADE;
CREATE TABLE data_mart.fact_failures (
    failure_id                                  INTEGER PRIMARY KEY,
    fdic_certificate_number                     INTEGER,
    institution_name                            TEXT NOT NULL,
    headquarters_state_code                     CHAR(2),
    failure_date                                DATE,
    failure_quarter_end                         DATE REFERENCES data_mart.dim_date_quarterly (quarter_end_date),
    failure_year                                INTEGER,
    resolution_type                             TEXT,
    transaction_type_code                       TEXT,
    charter_class_code                          TEXT,
    total_assets_at_failure_thousands           BIGINT,
    total_deposits_at_failure_thousands         BIGINT,
    estimated_loss_to_insurance_fund_thousands  BIGINT,
    insurance_fund_code                         TEXT,
    acquiring_institution_name                  TEXT
);

INSERT INTO data_mart.fact_failures
SELECT
    failure_id,
    fdic_certificate_number,
    institution_name,
    headquarters_state_code,
    failure_date,
    CASE
        WHEN failure_date IS NULL THEN NULL
        ELSE (DATE_TRUNC('quarter', failure_date)::date + INTERVAL '3 months' - INTERVAL '1 day')::date
    END AS failure_quarter_end,
    failure_year,
    resolution_type,
    transaction_type_code,
    charter_class_code,
    total_assets_at_failure_thousands,
    total_deposits_at_failure_thousands,
    estimated_loss_to_insurance_fund_thousands,
    insurance_fund_code,
    acquiring_institution_name
FROM data_warehouse.failures;

COMMIT;