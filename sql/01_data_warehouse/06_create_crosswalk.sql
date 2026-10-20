-- One row per distinct CFPB company name. Crosswalk gives nullable link to a FDIC charter: an unmatched company is
-- still valid row.


BEGIN;

DROP TABLE IF EXISTS data_warehouse.crosswalk CASCADE;
CREATE TABLE data_warehouse.crosswalk (
    company_name            TEXT    PRIMARY KEY CHECK (btrim(company_name) <> ''),
    company_name_normalized TEXT    NOT NULL,
    match_method            TEXT    NOT NULL, --'exact', 'suffix_stripped', 'manual_override', or 'unmatched'
    company_category        TEXT    NOT NULL, --'bank' for matched rows; a non-bank category otherwise
    fdic_certificate_number INTEGER REFERENCES data_warehouse.institutions (fdic_certificate_number)
);

INSERT INTO data_warehouse.crosswalk
SELECT company_name, company_name_normalized, match_method, company_category, matched_fdic_certificate_number
FROM clean.company_crosswalk;

COMMIT;