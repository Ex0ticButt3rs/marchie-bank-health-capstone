-- One row per certificate per quarter-end = "bank on same axis" required table from Part 3 including balance sheet,
-- de-cumulated income, macro rates, quarter's matched complaint count, etc.

-- Complaints are dated daily in data warehouse; however, this fact table needs them at quarter grain. Therefore,
-- bucketing rule: DATE_TRUNC('quarter', date_received) + 3 months - 1 day
-- maps a complaint on 30 June to Q2 and 1 July to Q3. Same rule applied to financials report_date, already a quarter-end.

-- Within this fact table, complaints count only those whose company matched an FDIC charter. Unmatched complaints are
-- visible on Complaints page via fact_complaints, not here.


BEGIN;

DROP TABLE IF EXISTS data_mart.fact_bank_quarter CASCADE;
CREATE TABLE data_mart.fact_bank_quarter (
    fdic_certificate_number              INTEGER NOT NULL REFERENCES data_mart.dim_bank (fdic_certificate_number),
    quarter_end_date                     DATE    NOT NULL REFERENCES data_mart.dim_date_quarterly (quarter_end_date),

    -- Balance sheet, per quarter end, thousands of dollars.
    total_assets_thousands               BIGINT,
    total_deposits_thousands             BIGINT,
    domestic_deposits_thousands          BIGINT,
    uninsured_deposits_thousands         BIGINT,
    total_equity_thousands               BIGINT,
    net_loans_and_leases_thousands       BIGINT,
    noncurrent_loans_thousands           BIGINT,
    loan_loss_allowance_thousands        BIGINT,

    -- Income statement, per quarter end, thousands of dollars.
    net_income_quarterly_thousands       BIGINT,
    provision_for_credit_losses_quarterly_thousands BIGINT,

    -- Ratios, already annualized by FDIC, expressed as percentages.
    return_on_assets_percent             NUMERIC,
    return_on_equity_percent             NUMERIC,
    equity_to_assets_percent             NUMERIC,
    noncurrent_loan_rate_percent         NUMERIC,
    nonperforming_assets_rate_percent    NUMERIC,
    net_interest_margin_percent          NUMERIC,

    -- Federal Reserve Economic Data (FRED)
    federal_funds_rate_percent           NUMERIC,
    unemployment_rate_percent            NUMERIC,
    thirty_year_mortgage_rate_percent    NUMERIC,
    ten_year_treasury_yield_percent      NUMERIC,

    -- Complaints only from companies matching an FDIC charter. Unmatched visible on Complaints page via fact_complaints
    matched_complaints                   INTEGER NOT NULL DEFAULT 0,

    PRIMARY KEY (fdic_certificate_number, quarter_end_date)
);

INSERT INTO data_mart.fact_bank_quarter (
    fdic_certificate_number, quarter_end_date, total_assets_thousands, total_deposits_thousands, domestic_deposits_thousands,
    uninsured_deposits_thousands, total_equity_thousands, net_loans_and_leases_thousands, noncurrent_loans_thousands,
    loan_loss_allowance_thousands, net_income_quarterly_thousands, provision_for_credit_losses_quarterly_thousands,
    return_on_assets_percent, return_on_equity_percent, equity_to_assets_percent, noncurrent_loan_rate_percent,
    nonperforming_assets_rate_percent, net_interest_margin_percent, federal_funds_rate_percent, unemployment_rate_percent,
    thirty_year_mortgage_rate_percent, ten_year_treasury_yield_percent, matched_complaints
)
SELECT
    f.fdic_certificate_number, f.report_date, f.total_assets_thousands, f.total_deposits_thousands,
    f.domestic_deposits_thousands, f.uninsured_deposits_thousands, f.total_equity_thousands,
    f.net_loans_and_leases_thousands, f.noncurrent_loans_thousands, f.loan_loss_allowance_thousands,
    f.net_income_quarterly_thousands, f.provision_for_credit_losses_quarterly_thousands, f.return_on_assets_percent,
    f.return_on_equity_percent, f.equity_to_assets_percent, f.noncurrent_loan_rate_percent,
    f.nonperforming_assets_rate_percent, f.net_interest_margin_percent, m.federal_funds_rate_percent,
    m.unemployment_rate_percent, m.thirty_year_mortgage_rate_percent, m.ten_year_treasury_yield_percent,
    COALESCE(c.matched_complaints, 0)
FROM data_warehouse.financials f
-- Inner JOIN to dim_bank is intentional as it excludes 5,294 CERTs in clean.financials not in current FDIC directory
-- as those charters filed Call Reports before being absorbed or closed so they have no row in dim_bank and no valid "bank"
-- to filter on in report. Their financial history still lives in data_warehouse.financials for joins without dim_bank.
JOIN data_mart.dim_bank b ON b.fdic_certificate_number = f.fdic_certificate_number
LEFT JOIN data_warehouse.macro_quarterly m ON f.report_date = m.quarter_end_date
LEFT JOIN (
    SELECT
        co.fdic_certificate_number,
        (DATE_TRUNC('quarter', c.date_received)::date + INTERVAL '3 months' - INTERVAL '1 day')::date AS quarter_end_date,
        COUNT(*) AS matched_complaints
    FROM data_warehouse.complaints c
    JOIN data_warehouse.crosswalk co ON c.company_name = co.company_name
    WHERE co.fdic_certificate_number IS NOT NULL AND c.date_received IS NOT NULL
    GROUP BY co.fdic_certificate_number, (DATE_TRUNC('quarter', c.date_received)::date + INTERVAL '3 months' - INTERVAL '1 day')::date
) c
  ON c.fdic_certificate_number = f.fdic_certificate_number AND c.quarter_end_date = f.report_date;

CREATE INDEX idx_fact_bank_quarter_date ON data_mart.fact_bank_quarter (quarter_end_date);

COMMIT;