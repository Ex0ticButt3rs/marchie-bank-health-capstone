-- Overall monetary relief rate
SELECT
    COUNT(*) AS total_complaints,
    ROUND(100.0 * SUM(CASE WHEN company_response_to_consumer = 'Closed with monetary relief' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS monetary_relief_pct
FROM data_mart.fact_complaints;

-- Monetary relief rate: Banks vs Non-Banks
SELECT
    cw.match_method = 'unmatched' AS is_unmatched,
    COUNT(*) AS complaints,
    ROUND(100.0 * SUM(CASE WHEN c.company_response_to_consumer = 'Closed with monetary relief' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS monetary_relief_pct
FROM data_mart.fact_complaints c
JOIN data_mart.dim_crosswalk cw ON c.company_name = cw.company_name
GROUP BY is_unmatched;

-- Monetary relief rate for the top 5 banks by complaint volume
WITH top_banks AS (
    SELECT cw.fdic_certificate_number, COUNT(*) AS complaints
    FROM data_mart.fact_complaints c
    JOIN data_mart.dim_crosswalk cw ON c.company_name = cw.company_name
    WHERE cw.fdic_certificate_number IS NOT NULL
    GROUP BY cw.fdic_certificate_number
    ORDER BY complaints DESC
    LIMIT 5
)
SELECT
    b.institution_name,
    tb.complaints,
    ROUND(100.0 * SUM(CASE WHEN c.company_response_to_consumer = 'Closed with monetary relief' THEN 1 ELSE 0 END) / COUNT(*), 1)
        AS monetary_relief_pct
FROM data_mart.fact_complaints c
JOIN data_mart.dim_crosswalk cw ON c.company_name = cw.company_name
JOIN top_banks tb ON cw.fdic_certificate_number = tb.fdic_certificate_number
JOIN data_mart.dim_bank b ON tb.fdic_certificate_number = b.fdic_certificate_number
GROUP BY b.institution_name, tb.complaints
ORDER BY tb.complaints DESC;