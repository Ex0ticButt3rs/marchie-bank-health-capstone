-- Demonstrate indexes with EXPLAIN before and after as well as noting where an index was tried but not used. Read-only
-- with respect to loaded data. Creates and drops indexes only. File ends with a safety net so re-running leaves schema unchanged.

-- Prerequisite: run_all_sql.sql has been run at least once, so data_mart.* has rows and statistics.

-- Plans are shown with EXPLAIN (ANALYZE, BUFFERS, COSTS OFF). Full plan outputs and reasoning behind each kept/rejected
-- index are in documentation/findings.md section "Indexes".

-- Report is Power BI Import mode: it pulls mart into VertiPaq during refresh and answers every visual from memory, so
-- PostgreSQL indexes are not consulted when a user opens a page. Indexes still serve refresh path, analysis queries in
-- sql/03_directed_analysis/ and sql/04_open_ended_analysis/, and any future DirectQuery consumer of the mart. Demos
-- below prove that kept indexes change plan when respective queries are run; rejected shapes in Demo 4 are a
-- DirectQuery report pattern that this report does not support.

-- VACUUM ANALYZE runs between CREATE INDEX and second EXPLAIN. Without it, the visibility map is not clean immediately
-- after CREATE INDEX and PostgresSQL will not choose Index Only Scan. See findings.md §1.6 for details.

-- Outcomes, for reference:
--   Demo 1 (idx_fact_complaints_date)        -- index kept.
--   Demo 2 (idx_fact_bank_quarter_date)      -- index kept.
--   Demo 3 (idx_fact_complaints_company)     -- index kept.
--   Demo 4 (fact_bank_quarter_assets_sort)   -- two shapes tried; both removed. Both are
--                                               chosen by the planner, but neither is worth
--                                               keeping: the query shape is a DirectQuery
--                                               report pattern, and this report is Import mode
--                                               (it answers visuals from VertiPaq, not from
--                                               PostgreSQL). The no-index plan already returns
--                                               in under 1 ms for the same shape. Reasoning is
--                                               in findings.md section "Indexes".


\set ON_ERROR_STOP on


\echo ''
\echo '================================================================================================='
\echo 'Bank Health capstone - index demonstrations'
\echo 'Source: sql/05_index_demos.sql'
\echo '================================================================================================='
\echo ''


-- =====================================================================
-- DEMO 1: idx_fact_complaints_date -- index kept
-- =====================================================================

\echo '----------------------------------------------------------------------------------------------'
\echo 'DEMO 1 - idx_fact_complaints_date'
\echo 'Query: monthly complaint trend for a single year.'
\echo '----------------------------------------------------------------------------------------------'
\echo ''

DROP INDEX IF EXISTS data_mart.idx_fact_complaints_date;

\echo '--- BEFORE (no index on date_received) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT date_trunc('month', date_received) AS month, COUNT(*)
FROM data_mart.fact_complaints
WHERE date_received >= '2023-01-01' AND date_received < '2024-01-01'
GROUP BY 1
ORDER BY 1;

CREATE INDEX idx_fact_complaints_date ON data_mart.fact_complaints (date_received);

-- Make the visibility map clean so Index Only Scan is eligible.
VACUUM ANALYZE data_mart.fact_complaints;

\echo ''
\echo '--- AFTER (index on date_received, visibility map clean) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT date_trunc('month', date_received) AS month, COUNT(*)
FROM data_mart.fact_complaints
WHERE date_received >= '2023-01-01' AND date_received < '2024-01-01'
GROUP BY 1
ORDER BY 1;

\echo ''
\echo 'Demo 1 result: index kept.'
\echo ''


-- =====================================================================
-- DEMO 2: idx_fact_bank_quarter_date -- index kept
-- =====================================================================

\echo '----------------------------------------------------------------------------------------------'
\echo 'DEMO 2 - idx_fact_bank_quarter_date'
\echo 'Query: industry-wide total assets at one quarter-end.'
\echo '----------------------------------------------------------------------------------------------'
\echo ''

DROP INDEX IF EXISTS data_mart.idx_fact_bank_quarter_date;

\echo '--- BEFORE (no index on quarter_end_date) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT quarter_end_date, SUM(total_assets_thousands) AS total_assets
FROM data_mart.fact_bank_quarter
WHERE quarter_end_date = '2026-06-30'
GROUP BY quarter_end_date;

CREATE INDEX idx_fact_bank_quarter_date ON data_mart.fact_bank_quarter (quarter_end_date);

VACUUM ANALYZE data_mart.fact_bank_quarter;

\echo ''
\echo '--- AFTER (index on quarter_end_date, visibility map clean) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT quarter_end_date, SUM(total_assets_thousands) AS total_assets
FROM data_mart.fact_bank_quarter
WHERE quarter_end_date = '2026-06-30'
GROUP BY quarter_end_date;

\echo ''
\echo 'Demo 2 result: index kept.'
\echo ''


-- =====================================================================
-- DEMO 3: idx_fact_complaints_company -- index kept
-- =====================================================================

\echo '----------------------------------------------------------------------------------------------'
\echo 'DEMO 3 - idx_fact_complaints_company'
\echo 'Query: top 20 companies by complaint volume.'
\echo '----------------------------------------------------------------------------------------------'
\echo ''

DROP INDEX IF EXISTS data_mart.idx_fact_complaints_company;

\echo '--- BEFORE (no index on company_name) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT company_name, COUNT(*)
FROM data_mart.fact_complaints
GROUP BY company_name
ORDER BY COUNT(*) DESC
LIMIT 20;

CREATE INDEX idx_fact_complaints_company ON data_mart.fact_complaints (company_name);

-- Same reason as Demo 1: clean visibility map for Index Only Scan.
VACUUM ANALYZE data_mart.fact_complaints;

\echo ''
\echo '--- AFTER (index on company_name, visibility map clean) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT company_name, COUNT(*)
FROM data_mart.fact_complaints
GROUP BY company_name
ORDER BY COUNT(*) DESC
LIMIT 20;

\echo ''
\echo 'Demo 3 result: index kept.'
\echo ''


-- =====================================================================
-- DEMO 4: fact_bank_quarter_assets_sort -- two shapes tried, both removed
-- =====================================================================

\echo '----------------------------------------------------------------------------------------------'
\echo 'DEMO 4 - fact_bank_quarter_assets_sort'
\echo 'Query: top 20 banks by total assets for one quarter.'
\echo 'Tried: single-column DESC index on the sort column.'
\echo 'Tried: composite (quarter_end_date, total_assets_thousands DESC) index.'
\echo '----------------------------------------------------------------------------------------------'
\echo ''

DROP INDEX IF EXISTS data_mart.fact_bank_quarter_assets_sort;

\echo '--- BEFORE (no sort-column index) ---'

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT fdic_certificate_number, total_assets_thousands
FROM data_mart.fact_bank_quarter
WHERE quarter_end_date = '2026-06-30'
ORDER BY total_assets_thousands DESC
LIMIT 20;

\echo ''
\echo '--- AFTER single-column DESC index on total_assets_thousands ---'

CREATE INDEX fact_bank_quarter_assets_sort ON data_mart.fact_bank_quarter (total_assets_thousands DESC);

VACUUM ANALYZE data_mart.fact_bank_quarter;

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT fdic_certificate_number, total_assets_thousands
FROM data_mart.fact_bank_quarter
WHERE quarter_end_date = '2026-06-30'
ORDER BY total_assets_thousands DESC
LIMIT 20;

\echo ''
\echo '--- AFTER composite (quarter_end_date, total_assets_thousands DESC) index ---'

DROP INDEX IF EXISTS data_mart.fact_bank_quarter_assets_sort;
CREATE INDEX fact_bank_quarter_assets_sort ON data_mart.fact_bank_quarter (quarter_end_date, total_assets_thousands DESC);

VACUUM ANALYZE data_mart.fact_bank_quarter;

EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT fdic_certificate_number, total_assets_thousands
FROM data_mart.fact_bank_quarter
WHERE quarter_end_date = '2026-06-30'
ORDER BY total_assets_thousands DESC
LIMIT 20;

\echo ''
\echo 'Demo 4 result: both shapes removed. The single-column shape IS chosen, but the'
\echo 'plan walks the full index filtering by quarter, discarding 800 rows to find 20.'
\echo 'The composite shape is also chosen and reads the 20 rows directly. Both are'
\echo 'removed because this query shape is a DirectQuery pattern, and this report is'
\echo 'Import mode: the Bank Scorecard is answered from VertiPaq, not from PostgreSQL.'
\echo 'The no-index plan already returns in under 1 ms for the same shape, so the'
\echo 'write and vacuum cost is not justified even if the report were DirectQuery.'
\echo 'Reasoning is in findings.md section "Indexes".'
\echo ''

DROP INDEX IF EXISTS data_mart.fact_bank_quarter_assets_sort;


-- =====================================================================
-- SAFETY NET
-- =====================================================================

\echo '----------------------------------------------------------------------------------------------'
\echo 'SAFETY NET - ensure kept indexes exist and the rejected index does not'
\echo '----------------------------------------------------------------------------------------------'
\echo ''

-- Demos 1-3 drop and recreate indexes. If this file stops partway through,
-- ensure the kept indexes exist at the end of every run.
CREATE INDEX IF NOT EXISTS idx_fact_complaints_date     ON data_mart.fact_complaints (date_received);
CREATE INDEX IF NOT EXISTS idx_fact_complaints_company  ON data_mart.fact_complaints (company_name);
CREATE INDEX IF NOT EXISTS idx_fact_bank_quarter_date   ON data_mart.fact_bank_quarter (quarter_end_date);

-- Demo 4's index is removed on success. If the file stopped between CREATE and
-- DROP, this removes the leftover.
DROP INDEX IF EXISTS data_mart.fact_bank_quarter_assets_sort;

\echo ''
\echo '================================================================================================='
\echo 'End index demonstrations.'
\echo '================================================================================================='
\echo ''