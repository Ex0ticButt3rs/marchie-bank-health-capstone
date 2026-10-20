-- One row per failure or assistance transaction since 1934.
-- failure_id is synthetic key assigned at load time in clean (1..N in file order).
-- CERT is nullable: 488 rows carry no certificate. These rows still enter model because failure event exists even when
-- charter reference does not.
-- No FK on CERT because some pre-2000 failures reference charters that are not in current institutions file.

-- fdic_failures.csv	One row per failure or assistance transaction since 1934


BEGIN;

DROP TABLE IF EXISTS data_warehouse.failures CASCADE;
CREATE TABLE data_warehouse.failures (
    failure_id                                  INTEGER  PRIMARY KEY,
    fdic_certificate_number                     INTEGER,
    institution_name                            TEXT     NOT NULL CHECK (btrim(institution_name) <> ''),
    headquarters_city                           TEXT,
    headquarters_state_code                     CHAR(2)  REFERENCES data_warehouse.state (state_code),
    failure_date                                DATE,
    failure_year                                INTEGER,
    resolution_date                             DATE,
    -- 'FAILURE' or 'ASSISTANCE'.
    resolution_type                             TEXT,
    -- PA, PI, P&A, PO, IDT, A/A and rarer assistance forms. See DATA_DICTIONARY.
    transaction_type_code                       TEXT,
    charter_class_code                          TEXT     REFERENCES data_warehouse.charter_class (charter_class_code),
    total_assets_at_failure_thousands           BIGINT,
    total_deposits_at_failure_thousands         BIGINT,
    estimated_loss_to_insurance_fund_thousands  BIGINT,
    uninsured_deposits_at_failure_thousands     BIGINT,
    insurance_fund_code                         TEXT,
    acquiring_institution_name                  TEXT,
    acquiring_city                              TEXT,
    acquiring_state_code                        CHAR(2)  REFERENCES data_warehouse.state (state_code),
    fdic_press_release_url                      TEXT,
    fdic_comments                               TEXT
);

INSERT INTO data_warehouse.failures
SELECT failure_id, fdic_certificate_number, institution_name, headquarters_city, headquarters_state_code, failure_date,
    failure_year, resolution_date, resolution_type, transaction_type_code, charter_class_code,
    total_assets_at_failure_thousands, total_deposits_at_failure_thousands, estimated_loss_to_insurance_fund_thousands,
    uninsured_deposits_at_failure_thousands, insurance_fund_code, acquiring_institution_name, acquiring_city,
    acquiring_state_code, fdic_press_release_url, fdic_comments
FROM clean.failures;

COMMIT;