-- Coverage by method
SELECT cw.match_method,
       COUNT(DISTINCT cw.company_name) AS companies,
       COUNT(c.complaint_id)           AS complaints,
-- OVER () with empty window turns SUM(COUNT(...)) into grand total across all rows in result, ignoring GROUP BY
       ROUND(100.0 * COUNT(c.complaint_id) / SUM(COUNT(c.complaint_id)) OVER (), 2) AS pct
FROM data_mart.dim_crosswalk cw
JOIN data_mart.fact_complaints c ON c.company_name = cw.company_name
GROUP BY cw.match_method
ORDER BY complaints DESC;

-- Unmatched remainder by category
SELECT cw.company_category,
       COUNT(DISTINCT cw.company_name) AS companies,
       COUNT(c.complaint_id)           AS complaints,
-- OVER () with empty window turns SUM(COUNT(...)) into grand total across all rows in result, ignoring GROUP BY
       ROUND(100.0 * COUNT(c.complaint_id) / SUM(COUNT(c.complaint_id)) OVER (), 2) AS pct
FROM data_mart.dim_crosswalk cw
JOIN data_mart.fact_complaints c ON c.company_name = cw.company_name
WHERE cw.match_method = 'unmatched'
GROUP BY cw.company_category
ORDER BY complaints DESC;