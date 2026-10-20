-- Bank count and concentration at start, middle, and end of window
SELECT report_year,
       ROUND(AVG(banks_reporting), 0)   AS avg_banks,
       ROUND(AVG(top_10_share), 4)      AS top_10_share,
       ROUND(AVG(top_100_share), 4)     AS top_100_share,
       ROUND(AVG(herfindahl_hirschman_index), 0) AS avg_hhi
FROM data_mart.fact_concentration fc
JOIN data_mart.dim_date_quarterly dd USING (quarter_end_date)
WHERE report_year IN (2008, 2016, 2026)
GROUP BY report_year
ORDER BY report_year;

-- Failures per year for same window 2008-2026 to separate failure from merger
SELECT failure_year, COUNT(*) AS failures
FROM data_mart.fact_failures
WHERE failure_year BETWEEN 2008 AND 2026
GROUP BY failure_year
ORDER BY failure_year;

-- Total failures and total decline in bank count
SELECT
    (SELECT COUNT(*) FROM data_mart.fact_failures WHERE failure_year BETWEEN 2008 AND 2026) AS total_failures,
    (SELECT COUNT(DISTINCT fdic_certificate_number) FROM data_mart.fact_bank_quarter WHERE quarter_end_date = '2008-03-31')
  - (SELECT COUNT(DISTINCT fdic_certificate_number) FROM data_mart.fact_bank_quarter WHERE quarter_end_date = '2026-06-30')
        AS net_decline;