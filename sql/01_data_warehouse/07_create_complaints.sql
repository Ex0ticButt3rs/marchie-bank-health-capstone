-- One row per complaint, 2019-01-01 through 2026-06-30.
-- company_name is foreign key to data_warehouse.crosswalk; every complaint names a company.
-- harmonized_product column collapses August 2023 CFPB relabel so reports show one product name per product rather than
-- two eras of labels.

-- cfpb_complaints.csv	One row per complaint received 2019-01-01 to 2026-06-30


BEGIN;

DROP TABLE IF EXISTS data_warehouse.complaints CASCADE;
CREATE TABLE data_warehouse.complaints (
    complaint_id                 BIGINT  PRIMARY KEY,
    date_received                DATE,
    date_sent_to_company         DATE,
    company_name                 TEXT    NOT NULL REFERENCES data_warehouse.crosswalk (company_name),
    harmonized_product           TEXT    NOT NULL REFERENCES data_warehouse.product (harmonized_product),
    sub_product                  TEXT,
    issue                        TEXT    REFERENCES data_warehouse.issue (issue),
    sub_issue                    TEXT,
    company_public_response      TEXT,
    company_response_to_consumer TEXT    REFERENCES data_warehouse.response_type (response_type),
    is_timely_response           BOOLEAN,
    consumer_state_code          CHAR(2) REFERENCES data_warehouse.state (state_code),
    -- Preserved as-is: CFPB masks last two digits on small ZIPs (e.g. 304XX).
    consumer_zip_code            TEXT,
    consumer_tags                TEXT,
    submitted_via_channel        TEXT    REFERENCES data_warehouse.submission_channel (channel)
);

INSERT INTO data_warehouse.complaints
SELECT complaint_id, date_received, date_sent_to_company, company_name, harmonized_product, sub_product, issue, sub_issue,
    company_public_response, company_response_to_consumer, is_timely_response, consumer_state_code, consumer_zip_code,
    consumer_tags, submitted_via_channel
FROM clean.complaints;

CREATE INDEX idx_complaints_date    ON data_warehouse.complaints (date_received);
CREATE INDEX idx_complaints_company ON data_warehouse.complaints (company_name);
CREATE INDEX idx_complaints_product ON data_warehouse.complaints (harmonized_product);

COMMIT;