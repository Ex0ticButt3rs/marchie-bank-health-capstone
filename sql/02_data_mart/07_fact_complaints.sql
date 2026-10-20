-- One row per complaint. Preserves every complaint dimension so PowerBI Complaints page can slice by product, response,
-- channel, state, and time at once.

-- company_name references dim_crosswalk holding both matched and unmatched companies. Report's matched-share calculation
-- uses dim_crosswalk.match_method.
-- Per bank complaint count on fact_bank_quarter is separate aggregate; this fact table does not double as that.

-- cfpb_complaints.csv	One row per complaint received 2019-01-01 to 2026-06-30


BEGIN;

DROP TABLE IF EXISTS data_mart.fact_complaints CASCADE;
CREATE TABLE data_mart.fact_complaints (
    complaint_id                 BIGINT PRIMARY KEY,
    date_received                DATE NOT NULL REFERENCES data_mart.dim_date_daily (daily_date),
    company_name                 TEXT NOT NULL REFERENCES data_mart.dim_crosswalk (company_name),
    harmonized_product           TEXT NOT NULL,
    sub_product                  TEXT,
    issue                        TEXT,
    sub_issue                    TEXT,
    company_public_response      TEXT,
    company_response_to_consumer TEXT,
    is_timely_response           BOOLEAN,
    consumer_state_code          CHAR(2),
    consumer_zip_code            TEXT,
    consumer_tags                TEXT,
    submitted_via_channel        TEXT
);

INSERT INTO data_mart.fact_complaints
SELECT complaint_id, date_received, company_name, harmonized_product, sub_product, issue, sub_issue, company_public_response,
    company_response_to_consumer, is_timely_response, consumer_state_code, consumer_zip_code, consumer_tags,
    submitted_via_channel
FROM data_warehouse.complaints;

CREATE INDEX idx_fact_complaints_date    ON data_mart.fact_complaints (date_received);
CREATE INDEX idx_fact_complaints_company ON data_mart.fact_complaints (company_name);

COMMIT;