-- One row per certificate per quarter end, 2006 Q1 through 2026 Q2.
-- Income statement fields carried both ways: *_ytd_thousands is raw YTD figure as reported, *_quarterly_thousands is
-- de-cumulated value computed in clean. YTD is kept alongside so can reconcile back to Call Report.
-- Balance sheet fields (assets, deposits, equity, loans) are point in time.

-- fdic_financials.csv	One row per institution per quarter-end, 2006 Q1 to 2026 Q2


BEGIN;

DROP TABLE IF EXISTS data_warehouse.financials CASCADE;
CREATE TABLE data_warehouse.financials (
    -- No FK on data_warehouse.institutions (fdic_certificate_number) as 5,294 CERTs in clean.financials are not in
    -- clean.institutions. These are charters that filed Call Reports before being absorbed or closed and are no longer
    -- in current FDIC directory. Column instead is retained as a plain integer for join attempts for analysis.
    fdic_certificate_number                         INTEGER  NOT NULL,
    report_date                                     DATE     NOT NULL,
    report_year                                     INTEGER  NOT NULL,
    report_quarter                                  INTEGER  NOT NULL CHECK (report_quarter BETWEEN 1 AND 4),

    -- Balance sheet, point in time, thousands of dollars.
    total_assets_thousands                          BIGINT,
    total_deposits_thousands                        BIGINT,
    domestic_deposits_thousands                     BIGINT,
    uninsured_deposits_thousands                    BIGINT,
    total_equity_thousands                          BIGINT,
    tier_one_risk_based_capital_thousands           BIGINT,
    net_loans_and_leases_thousands                  BIGINT,
    gross_loans_and_leases_thousands                BIGINT,
    real_estate_loans_thousands                     BIGINT,
    loan_loss_allowance_thousands                   BIGINT,
    noncurrent_loans_thousands                      BIGINT,
    assets_30_to_89_days_past_due_thousands         BIGINT,
    assets_90_plus_days_past_due_thousands          BIGINT,
    securities_held_thousands                       BIGINT,

    -- Ratios, already annualized by FDIC, expressed as percentages.
    return_on_assets_percent                        NUMERIC,
    return_on_equity_percent                        NUMERIC,
    equity_to_assets_percent                        NUMERIC,
    noncurrent_loan_rate_percent                    NUMERIC,
    nonperforming_assets_rate_percent               NUMERIC,
    net_interest_margin_percent                     NUMERIC,

    -- Income statement, YTD as reported.
    net_income_ytd_thousands                        BIGINT,
    interest_income_ytd_thousands                   BIGINT,
    interest_expense_ytd_thousands                  BIGINT,
    noninterest_income_ytd_thousands                BIGINT,
    noninterest_expense_ytd_thousands               BIGINT,
    provision_for_credit_losses_ytd_thousands       BIGINT,

    -- Income statement, de-cumulated to quarter. NULL where prior quarter's YTD missing because quarterly figure is
    -- undefined not zero in such cases.
    net_income_quarterly_thousands                  BIGINT,
    interest_income_quarterly_thousands             BIGINT,
    interest_expense_quarterly_thousands            BIGINT,
    noninterest_income_quarterly_thousands          BIGINT,
    noninterest_expense_quarterly_thousands         BIGINT,
    provision_for_credit_losses_quarterly_thousands BIGINT,

    employee_count                                  INTEGER,
    domestic_office_count                           INTEGER,

    PRIMARY KEY (fdic_certificate_number, report_date)
);

INSERT INTO data_warehouse.financials
SELECT fdic_certificate_number, report_date, report_year, report_quarter, total_assets_thousands, total_deposits_thousands,
    domestic_deposits_thousands, uninsured_deposits_thousands, total_equity_thousands, tier_one_risk_based_capital_thousands,
    net_loans_and_leases_thousands, gross_loans_and_leases_thousands, real_estate_loans_thousands,
    loan_loss_allowance_thousands, noncurrent_loans_thousands, assets_30_to_89_days_past_due_thousands,
    assets_90_plus_days_past_due_thousands, securities_held_thousands, return_on_assets_percent, return_on_equity_percent,
    equity_to_assets_percent, noncurrent_loan_rate_percent, nonperforming_assets_rate_percent, net_interest_margin_percent,
    net_income_ytd_thousands, interest_income_ytd_thousands, interest_expense_ytd_thousands, noninterest_income_ytd_thousands,
    noninterest_expense_ytd_thousands, provision_for_credit_losses_ytd_thousands, net_income_quarterly_thousands,
    interest_income_quarterly_thousands, interest_expense_quarterly_thousands, noninterest_income_quarterly_thousands,
    noninterest_expense_quarterly_thousands, provision_for_credit_losses_quarterly_thousands, employee_count, domestic_office_count
FROM clean.financials;

CREATE INDEX idx_financials_date ON data_warehouse.financials (report_date);

COMMIT;