-- One row per FDIC certificate. Every row in clean.institutions enters model (active and closed).
-- holding_company_name is plain column instead of separate entity because no CERT in source data has ever been associated
-- with more than one NAMEHCR (verified in clean.institutions before load).


BEGIN;

DROP TABLE IF EXISTS data_warehouse.institutions CASCADE;
CREATE TABLE data_warehouse.institutions (
    fdic_certificate_number  INTEGER  PRIMARY KEY,
    institution_name         TEXT     NOT NULL CHECK (btrim(institution_name) <> ''),
    headquarters_city        TEXT,
    headquarters_state_code  CHAR(2)  REFERENCES data_warehouse.state (state_code),
    headquarters_zip_code    TEXT,
    total_assets_thousands   BIGINT   CHECK (total_assets_thousands IS NULL OR total_assets_thousands >= 0),
    total_deposits_thousands BIGINT   CHECK (total_deposits_thousands IS NULL OR total_deposits_thousands >= 0),
    -- ACTIVE = 1 mapped to boolean in clean; NOT NULL means every row has a definite status.
    is_active                BOOLEAN  NOT NULL,
    charter_class_code       TEXT     REFERENCES data_warehouse.charter_class (charter_class_code),
    holding_company_name     TEXT,
    federal_reserve_rssd_id  TEXT,
    established_date         DATE,
    end_date                 DATE,
    website_address          TEXT
);

INSERT INTO data_warehouse.institutions
SELECT fdic_certificate_number, institution_name, headquarters_city, headquarters_state_code, headquarters_zip_code,
    total_assets_thousands, total_deposits_thousands, is_active, charter_class_code, holding_company_name,
    federal_reserve_rssd_id, established_date, end_date, website_address
FROM clean.institutions;

COMMIT;