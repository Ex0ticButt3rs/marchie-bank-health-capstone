-- Yearly totals: complaints, distinct companies, complaints per company
SELECT dd.report_year,
       COUNT(*)                                AS complaints,
       COUNT(DISTINCT fc.company_name)         AS distinct_companies,
       ROUND(COUNT(*)::numeric / NULLIF(COUNT(DISTINCT fc.company_name), 0), 1) AS complaints_per_company
FROM data_mart.fact_complaints fc
JOIN data_mart.dim_date_daily dd ON dd.daily_date = fc.date_received
GROUP BY dd.report_year
ORDER BY dd.report_year;

-- Top 10 companies by complaint growth, 2019 vs 2025
WITH yearly AS (
    SELECT fc.company_name,
           EXTRACT(YEAR FROM fc.date_received)::int AS yr,
           COUNT(*) AS complaints
    FROM data_mart.fact_complaints fc
    WHERE EXTRACT(YEAR FROM fc.date_received) IN (2019, 2025)
    GROUP BY fc.company_name, yr
)
SELECT
    COALESCE(y2019.company_name, y2025.company_name) AS company_name,
    COALESCE(y2019.complaints, 0)                    AS complaints_2019,
    COALESCE(y2025.complaints, 0)                    AS complaints_2025,
    COALESCE(y2025.complaints, 0) - COALESCE(y2019.complaints, 0) AS growth
FROM (SELECT * FROM yearly WHERE yr = 2019) y2019
FULL OUTER JOIN (SELECT * FROM yearly WHERE yr = 2025) y2025 ON y2019.company_name = y2025.company_name
ORDER BY growth DESC
LIMIT 15;

-- Product mix shift, 2019 vs 2025
SELECT fc.harmonized_product,
       SUM(CASE WHEN EXTRACT(YEAR FROM fc.date_received) = 2019 THEN 1 ELSE 0 END) AS complaints_2019,
       SUM(CASE WHEN EXTRACT(YEAR FROM fc.date_received) = 2025 THEN 1 ELSE 0 END) AS complaints_2025
FROM data_mart.fact_complaints fc
WHERE EXTRACT(YEAR FROM fc.date_received) IN (2019, 2025)
GROUP BY fc.harmonized_product
ORDER BY complaints_2025 DESC;