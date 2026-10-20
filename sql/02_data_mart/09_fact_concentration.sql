-- Industry concentration by quarter. One row per quarter-end, three ratios: top 10 asset share, top 100 asset share, and
-- Herfindahl-Hirschman Index (HHI) as alternative measure of concentration.

-- HHI (Herfindahl-Hirschman Index): single number concentration measure. 0–10,000 scale; under 1,500 is "unconcentrated",
-- over 2,500 is "highly concentrated". Banks' HHI sits low but trend tells story.

-- Computed here rather than in Power BI because ranking requires a full bank × quarter materialization in DAX that exceeded
-- report's memory budget... Computed once in SQL to be read cheaply by report.

-- Assets are the point-in-time balance sheet figure at each quarter-end, in thousands. Shares sum to 1.0 at each quarter.


BEGIN;

DROP TABLE IF EXISTS data_mart.fact_concentration CASCADE;
CREATE TABLE data_mart.fact_concentration (
    quarter_end_date            DATE PRIMARY KEY REFERENCES data_mart.dim_date_quarterly (quarter_end_date),
    banks_reporting             INTEGER NOT NULL,
    total_assets_thousands      BIGINT  NOT NULL,
    top_10_assets_thousands     BIGINT NOT NULL,
    top_100_assets_thousands    BIGINT NOT NULL,
    top_10_share                NUMERIC(6,4) NOT NULL CHECK (top_10_share   BETWEEN 0 AND 1),
    top_100_share               NUMERIC(6,4) NOT NULL CHECK (top_100_share  BETWEEN 0 AND 1),
    herfindahl_hirschman_index  NUMERIC(8,2) NOT NULL
);

-- ranked = computes row number per bank per quarter
WITH ranked AS (
    SELECT
        quarter_end_date,
        fdic_certificate_number,
        total_assets_thousands,
        ROW_NUMBER() OVER (PARTITION BY quarter_end_date ORDER BY total_assets_thousands DESC NULLS LAST) AS bank_rank
    FROM data_mart.fact_bank_quarter
    WHERE total_assets_thousands IS NOT NULL
),
-- totals = computes per quarter bank count and total assets
totals AS (
    SELECT
        quarter_end_date,
        COUNT(*)                    AS banks_reporting,
        SUM(total_assets_thousands) AS total_assets_thousands
    FROM ranked
    GROUP BY quarter_end_date
),
-- per_quarter = joins ranked and totals then applies aggregate SUM(...) FILTER (...) and HHI calculation.
per_quarter AS (
    SELECT
        t.quarter_end_date,
        t.banks_reporting,
        t.total_assets_thousands,
        SUM(r.total_assets_thousands) FILTER (WHERE r.bank_rank <=  10) AS top_10_assets_thousands,
        SUM(r.total_assets_thousands) FILTER (WHERE r.bank_rank <= 100) AS top_100_assets_thousands,
        SUM(POWER(r.total_assets_thousands::numeric / NULLIF(t.total_assets_thousands, 0), 2) * 10000) AS hhi
    FROM ranked r
    JOIN totals t USING (quarter_end_date)
    GROUP BY t.quarter_end_date, t.banks_reporting, t.total_assets_thousands
)
INSERT INTO data_mart.fact_concentration
SELECT
    quarter_end_date,
    banks_reporting,
    total_assets_thousands,
    COALESCE(top_10_assets_thousands,  0),
    COALESCE(top_100_assets_thousands, 0),
    ROUND(top_10_assets_thousands::numeric  / NULLIF(total_assets_thousands, 0), 4),
    ROUND(top_100_assets_thousands::numeric / NULLIF(total_assets_thousands, 0), 4),
    ROUND(hhi, 2)
FROM per_quarter;

COMMIT;