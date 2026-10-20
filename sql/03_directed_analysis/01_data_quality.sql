-- Every rule with a non zero rows_failing ordered by impact
SELECT table_name, column_name, rule_name, rows_failing, action_taken
FROM data_quality_summary -- src/07_data_quality.py
WHERE rows_failing > 0
ORDER BY table_name, column_name, rows_failing DESC;

-- Crosswalk coverage summary
SELECT table_name, column_name, rule_name, rows_failing, action_taken
FROM data_quality_summary -- src/07_data_quality.py
WHERE rule_name IN ('crosswalk_matched', 'crosswalk_unmatched', 'crosswalk_complaint_coverage', 'data_vs_published_definitions');

-- Column profiling for highest null rates
SELECT table_name, column_name, row_count, null_count, ROUND(100.0 * null_count / NULLIF(row_count, 0), 2) AS pct_null
FROM data_quality_summary -- src/07_data_quality.py
WHERE rule_name = 'column profile' AND null_count > 0
ORDER BY pct_null DESC;