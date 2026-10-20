-- Load proving checks. These read from data warehouse but do not modify it as every query should return expected value.

\echo ''
\echo '================================================================================================='
\echo 'Bank Health capstone - load validation'
\echo 'Source: sql/validate_run_all_sql.sql'
\echo '================================================================================================='
\echo ''


\echo '----------------------------------------------------------------------------------------------'
\echo 'CHECK 1 - Row counts: clean vs data_warehouse'
\echo 'Expectation: clean_count equals wh_count on every row.'
\echo '----------------------------------------------------------------------------------------------'

SELECT 'institutions' AS table_name,
       (SELECT COUNT(*) FROM clean.institutions)          AS clean_count,
       (SELECT COUNT(*) FROM data_warehouse.institutions) AS wh_count
UNION ALL
SELECT 'financials',
       (SELECT COUNT(*) FROM clean.financials),
       (SELECT COUNT(*) FROM data_warehouse.financials)
UNION ALL
SELECT 'failures',
       (SELECT COUNT(*) FROM clean.failures),
       (SELECT COUNT(*) FROM data_warehouse.failures)
UNION ALL
SELECT 'complaints',
       (SELECT COUNT(*) FROM clean.complaints),
       (SELECT COUNT(*) FROM data_warehouse.complaints)
UNION ALL
SELECT 'crosswalk',
       (SELECT COUNT(*) FROM clean.company_crosswalk),
       (SELECT COUNT(*) FROM data_warehouse.crosswalk)
UNION ALL
SELECT 'macro_quarterly',
       (SELECT COUNT(*) FROM clean.macro_quarterly),
       (SELECT COUNT(*) FROM data_warehouse.macro_quarterly);

\echo ''
\echo 'Expected: institutions 27835, financials 523136, failures 4117, complaints 1077624, crosswalk 4114, macro_quarterly 82.'
\echo ''


\echo '----------------------------------------------------------------------------------------------'
\echo 'CHECK 2 - Primary key uniqueness'
\echo 'Expectation: failures = 0 on every row.'
\echo '----------------------------------------------------------------------------------------------'

SELECT 'institutions_pk_duplicates' AS check_name, COUNT(*) AS failures
FROM (SELECT fdic_certificate_number FROM data_warehouse.institutions
      GROUP BY 1 HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'financials_pk_duplicates', COUNT(*)
FROM (SELECT fdic_certificate_number, report_date FROM data_warehouse.financials
      GROUP BY 1, 2 HAVING COUNT(*) > 1) d
UNION ALL
SELECT 'complaints_pk_duplicates', COUNT(*)
FROM (SELECT complaint_id FROM data_warehouse.complaints
      GROUP BY 1 HAVING COUNT(*) > 1) d;

\echo ''


\echo '----------------------------------------------------------------------------------------------'
\echo 'CHECK 3 - Crosswalk coverage'
\echo 'Expectation: pct_matched = 61.65.'
\echo '----------------------------------------------------------------------------------------------'

SELECT ROUND(100.0 * SUM(CASE WHEN cw.fdic_certificate_number IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_matched
FROM data_warehouse.complaints c
JOIN data_warehouse.crosswalk cw USING (company_name);

\echo ''


\echo '----------------------------------------------------------------------------------------------'
\echo 'CHECK 4 - Spot check: JPMorgan Chase (CERT 628) at 2026-06-30'
\echo 'Expectation: wh_assets equals clean_assets.'
\echo '----------------------------------------------------------------------------------------------'

SELECT w.fdic_certificate_number,
       w.report_date,
       w.total_assets_thousands AS wh_assets,
       c.total_assets_thousands AS clean_assets,
       (w.total_assets_thousands = c.total_assets_thousands) AS match
FROM data_warehouse.financials w
JOIN clean.financials c USING (fdic_certificate_number, report_date)
WHERE w.fdic_certificate_number = 628 AND w.report_date = '2026-06-30';

\echo ''


\echo '================================================================================================='
\echo 'End validation.'
\echo '================================================================================================='
\echo ''