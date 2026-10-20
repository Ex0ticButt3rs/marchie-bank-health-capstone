# Findings

Bank Health and Customer Complaints Capstone. Written to be readable on its own;
all queries referenced here are in `sql/03_directed_analysis/` and
`sql/04_open_ended_analysis/`.

## Table of Contents

1. [Indexes](#1-indexes)
   - [1.1 Overview](#11-overview)
   - [1.2 Demo 1 - idx_fact_complaints_date (kept)](#12-demo-1---idx_fact_complaints_date-kept)
   - [1.3 Demo 2 - idx_fact_bank_quarter_date (kept)](#13-demo-2---idx_fact_bank_quarter_date-kept)
   - [1.4 Demo 3 - idx_fact_complaints_company (kept)](#14-demo-3---idx_fact_complaints_company-kept)
   - [1.5 Demo 4 - fact_bank_quarter_assets_sort (tried, both shapes removed)](#15-demo-4---fact_bank_quarter_assets_sort-tried-both-shapes-removed)
   - [1.6 Why VACUUM ANALYZE sits in every demo](#16-why-vacuum-analyze-sits-in-every-demo)
2. [Data Quality](#2-data-quality)
   - [2.1 Case-only duplicate company names](#21-case-only-duplicate-company-names)
   - [2.2 Charter class code `MI`](#22-charter-class-code-mi)
   - [2.3 Charter class code `CU`](#23-charter-class-code-cu)
   - [2.4 Two directions of divergence](#24-two-directions-of-divergence)
   - [2.5 Empty `BKCLASS` on CERT 15656](#25-empty-bkclass-on-cert-15656)
   - [2.6 Other cleaning decisions worth noting](#26-other-cleaning-decisions-worth-noting)
3. [Power BI Report Measures and Their Sources](#3-power-bi-report-measures-and-their-sources)
   - [3.1 Definitions used across pages](#31-definitions-used-across-pages)
   - [3.2 Verified against SQL](#32-verified-against-sql)
4. [Industry Concentration](#4-industry-concentration)
   - [4.1 Bank size bands](#41-bank-size-bands)
   - [4.2 Two definitions of "a bank"](#42-two-definitions-of-a-bank)
5. [Bank Scorecard](#5-bank-scorecard-complaints-per-deposit-falls-with-size-but-not-because-size-matters)
6. [Failures](#6-failures-2023-was-not-a-smaller-2008)
   - [6.1 What 2009 teaches that 2008 does not](#61-what-2009-teaches-that-2008-does-not)
   - [6.2 The 1930s peak](#62-the-1930s-peak)
   - [6.3 Multi-charter holding companies of the late 1980s](#63-multi-charter-holding-companies-of-the-late-1980s)
7. [Directed Analysis](#7-directed-analysis)
   - [7.1 Q1 - Data quality](#71-q1---data-quality)
     - [7.1.1 Summary of data quality rules applied](#711-summary-of-data-quality-rules-applied)
     - [7.1.2 Types of missingness](#712-types-of-missingness)
     - [7.1.3 Rules that materially changed the data](#713-rules-that-materially-changed-the-data)
     - [7.1.4 Invalid values that were nulled](#714-invalid-values-that-were-nulled)
     - [7.1.5 Published definitions that disagree with the data](#715-published-definitions-that-disagree-with-the-data)
     - [7.1.6 What changed as a result](#716-what-changed-as-a-result)
   - [7.2 Q2 - Crosswalk](#72-q2---crosswalk)
   - [7.3 Q3 - Consolidation](#73-q3---consolidation)
     - [7.3.1 Bank count and concentration](#731-bank-count-and-concentration)
     - [7.3.2 Failure or merger](#732-failure-or-merger)
     - [7.3.3 Consolidation conclusion](#733-consolidation-conclusion)
8. [Open-Ended Analysis](#8-open-ended-analysis)
   - [8.1 Part 6 | Required: The complaint boom](#81-part-6--required-the-complaint-boom--three-patterns-not-one)
     - [8.1.1 Broad-based growth in consumer awareness](#811-broad-based-growth-in-consumer-awareness)
     - [8.1.2 Credit bureaus appear from nowhere](#812-credit-bureaus-appear-from-nowhere)
     - [8.1.3 New companies in the CFPB universe](#813-new-companies-in-the-cfpb-universe)
     - [8.1.4 Product-mix evidence](#814-product-mix-evidence)
     - [8.1.5 Conclusion](#815-conclusion)
   - [8.2 Part 6 | Personal Choice: Do banks pay up when the CFPB gets involved?](#82-part-6--personal-choice-do-banks-pay-up-when-the-cfpb-gets-involved)
     - [8.2.1 Overall picture](#821-overall-picture)
     - [8.2.2 Stark divide: Banks versus non-banks](#822-stark-divide-banks-versus-non-banks)
     - [8.2.3 Big banks](#823-big-banks)
     - [8.2.4 Conclusion](#824-conclusion)

---

## 1. Indexes

### 1.1 Overview

Demonstrations of indexes with `EXPLAIN` before and after such that any index that was tried but could not be shown to earn its keep is removed. Four indexes were tried. Three were kept and one was removed in two different shapes. The demonstrations are in `sql/05_index_demos.sql`; the plan output below is the actual run of that file, pasted verbatim.

The plans are `EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)`. Plan shape is the evidence instead of wall clock time. Timings are shown because the run reports them but the shape (which node reads which rows and how many) is what is being demonstrated.

### 1.2 Demo 1 - `idx_fact_complaints_date` (kept)

The query is the monthly complaint trend for a single year - the shape a Complaints page visual would use.

**BEFORE** (no index on `date_received`):

```
 Finalize GroupAggregate (actual time=206.068..208.002 rows=12 loops=1)
   Group Key: (date_trunc('month'::text, (date_received)::timestamp with time zone))
   Buffers: shared hit=848 read=35788
   ->  Gather Merge (actual time=206.059..207.988 rows=36 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=848 read=35788
         ->  Sort (actual time=202.410..202.412 rows=12 loops=3)
               Sort Key: (date_trunc('month'::text, (date_received)::timestamp with time zone))
               Sort Method: quicksort  Memory: 25kB
               Buffers: shared hit=848 read=35788
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Partial HashAggregate (actual time=202.367..202.381 rows=12 loops=3)
                     Group Key: date_trunc('month'::text, (date_received)::timestamp with time zone)
                     Batches: 1  Memory Usage: 121kB
                     Buffers: shared hit=832 read=35788
                     Worker 0:  Batches: 1  Memory Usage: 121kB
                     Worker 1:  Batches: 1  Memory Usage: 121kB
                     ->  Parallel Seq Scan on fact_complaints (actual time=0.230..195.058 rows=49982 loops=3)
                           Filter: ((date_received >= '2023-01-01'::date) AND (date_received < '2024-01-01'::date))
                           Rows Removed by Filter: 309226
                           Buffers: shared hit=832 read=35788
 Planning:
   Buffers: shared hit=112 dirtied=3
 Planning Time: 0.714 ms
 Execution Time: 208.296 ms
```

**AFTER** (`idx_fact_complaints_date`, visibility map clean):

```
 Sort (actual time=57.655..57.657 rows=12 loops=1)
   Sort Key: (date_trunc('month'::text, (date_received)::timestamp with time zone))
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=6 read=134
   ->  HashAggregate (actual time=57.637..57.648 rows=12 loops=1)
         Group Key: date_trunc('month'::text, (date_received)::timestamp with time zone)
         Batches: 1  Memory Usage: 121kB
         Buffers: shared hit=6 read=134
         ->  Index Only Scan using idx_fact_complaints_date on fact_complaints (actual time=0.067..37.883 rows=149945 loops=1)
               Index Cond: ((date_received >= '2023-01-01'::date) AND (date_received < '2024-01-01'::date))
               Heap Fetches: 0
               Buffers: shared hit=6 read=134
 Planning:
   Buffers: shared hit=36
 Planning Time: 0.244 ms
 Execution Time: 57.698 ms
```

The scan node changed from a `Parallel Seq Scan` over 1,077,624 rows to an `Index Only Scan` over the 149,945 rows the index points to, and the heap is never touched (`Heap Fetches: 0`). The aggregation stays a `HashAggregate` in both plans. Wall clock roughly halves; the plan shape change is the point.

The AFTER plan depends on `VACUUM ANALYZE` running between `CREATE INDEX` and the second `EXPLAIN`. Without it, the planner does not have a clean visibility map and falls back to `Index Scan`, not `Index Only Scan`. This is discussed in §1.6.

### 1.3 Demo 2 - `idx_fact_bank_quarter_date` (kept)

The query reads industry-wide total assets at one quarter-end - the shape an Industry page card would use. This is the cleanest demonstration in the file.

**BEFORE** (no index on `quarter_end_date`):

```
 Finalize GroupAggregate (actual time=74.182..76.142 rows=1 loops=1)
   Buffers: shared hit=1057 read=12885
   ->  Gather (actual time=73.520..76.130 rows=2 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=1057 read=12885
         ->  Partial GroupAggregate (actual time=71.389..71.390 rows=1 loops=3)
               Buffers: shared hit=1057 read=12885
               ->  Parallel Seq Scan on fact_bank_quarter (actual time=70.288..71.276 rows=1419 loops=3)
                     Filter: (quarter_end_date = '2026-06-30'::date)
                     Rows Removed by Filter: 171195
                     Buffers: shared hit=1057 read=12885
 Planning:
   Buffers: shared hit=53
 Planning Time: 0.247 ms
 Execution Time: 76.171 ms
```

**AFTER** (`idx_fact_bank_quarter_date`, visibility map clean):

```
 GroupAggregate (actual time=1.036..1.037 rows=1 loops=1)
   Buffers: shared hit=116 read=6
   ->  Index Scan using idx_fact_bank_quarter_date on fact_bank_quarter (actual time=0.101..0.740 rows=4257 loops=1)
         Index Cond: (quarter_end_date = '2026-06-30'::date)
         Buffers: shared hit=116 read=6
 Planning:
   Buffers: shared hit=12
 Planning Time: 0.211 ms
 Execution Time: 1.058 ms
```

The BEFORE plan scanned all 517,842 rows to find 4,257; the AFTER plan visits exactly those 4,257. The filter step disappears entirely - the index condition does the filtering. A single value filter on a column with 371 distinct values is the shape an index serves best, and this is the demo that shows it most clearly.

### 1.4 Demo 3 - `idx_fact_complaints_company` (kept)

The query is top 20 companies by complaint volume - the Complaints page ranking.

**BEFORE** (no index on `company_name`):

```
 Limit (actual time=130.630..131.184 rows=20 loops=1)
   Buffers: shared hit=1264 read=35372
   ->  Sort (actual time=130.628..131.180 rows=20 loops=1)
         Sort Key: (count(*)) DESC
         Sort Method: top-N heapsort  Memory: 27kB
         Buffers: shared hit=1264 read=35372
         ->  Finalize GroupAggregate (actual time=125.492..130.584 rows=4114 loops=1)
               Group Key: company_name
               Buffers: shared hit=1264 read=35372
               ->  Gather Merge (actual time=125.482..129.063 rows=8350 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=1264 read=35372
                     ->  Sort (actual time=122.818..122.990 rows=2783 loops=3)
                           Sort Key: company_name
                           Sort Method: quicksort  Memory: 243kB
                           Buffers: shared hit=1264 read=35372
                           Worker 0:  Sort Method: quicksort  Memory: 239kB
                           Worker 1:  Sort Method: quicksort  Memory: 241kB
                           ->  Partial HashAggregate (actual time=119.142..119.438 rows=2783 loops=3)
                                 Group Key: company_name
                                 Batches: 1  Memory Usage: 369kB
                                 Buffers: shared hit=1248 read=35372
                                 Worker 0:  Batches: 1  Memory Usage: 369kB
                                 Worker 1:  Batches: 1  Memory Usage: 369kB
                                 ->  Parallel Seq Scan on fact_complaints (actual time=0.020..43.239 rows=359208 loops=3)
                                       Buffers: shared hit=1248 read=35372
 Planning:
   Buffers: shared hit=16
 Planning Time: 0.127 ms
 Execution Time: 131.224 ms
```

**AFTER** (`idx_fact_complaints_company`, visibility map clean):

```
 Limit (actual time=73.113..74.534 rows=20 loops=1)
   Buffers: shared hit=2998 read=964
   ->  Sort (actual time=73.111..74.529 rows=20 loops=1)
         Sort Key: (count(*)) DESC
         Sort Method: top-N heapsort  Memory: 27kB
         Buffers: shared hit=2998 read=964
         ->  Finalize GroupAggregate (actual time=15.835..74.009 rows=4114 loops=1)
               Group Key: company_name
               Buffers: shared hit=2998 read=964
               ->  Gather Merge (actual time=15.820..73.129 rows=4271 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=2998 read=964
                     ->  Partial GroupAggregate (actual time=0.065..48.136 rows=1424 loops=3)
                           Group Key: company_name
                           Buffers: shared hit=2998 read=964
                           ->  Parallel Index Only Scan using idx_fact_complaints_company on fact_complaints (actual time=0.035..24.076 rows=359208 loops=3)
                                 Heap Fetches: 0
                                 Buffers: shared hit=2998 read=964
 Planning:
   Buffers: shared hit=32
 Planning Time: 0.147 ms
 Execution Time: 74.563 ms
```

The gain here is smaller than Demos 1 and 2 in wall clock (131 ms → 75 ms) because the BEFORE plan was already parallel. The interesting change is *inside* the plan: the `Partial HashAggregate + per-worker Sort` becomes `Partial GroupAggregate` alone, because the index delivers `company_name` in sorted order and the per-worker sort is no longer needed. The scan node changes from `Parallel Seq Scan` to `Parallel Index Only Scan` with `Heap Fetches: 0`. Same visibility map caveat as Demo 1.

### 1.5 Demo 4 - `fact_bank_quarter_assets_sort` (tried, both shapes removed)

The query is top 20 banks by total assets for one quarter - the shape a Bank Scorecard ranking visual would use against a DirectQuery source. Two index shapes were tried.

**BEFORE** (no sort-column index):

```
 Limit (actual time=0.992..0.995 rows=20 loops=1)
   Buffers: shared hit=122
   ->  Sort (actual time=0.991..0.992 rows=20 loops=1)
         Sort Key: total_assets_thousands DESC
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=122
         ->  Index Scan using idx_fact_bank_quarter_date on fact_bank_quarter (actual time=0.010..0.582 rows=4257 loops=1)
               Index Cond: (quarter_end_date = '2026-06-30'::date)
               Buffers: shared hit=122
 Planning:
   Buffers: shared hit=5
 Planning Time: 0.093 ms
 Execution Time: 1.008 ms
```

**AFTER single-column DESC index on `total_assets_thousands`**:

```
 Limit (actual time=0.947..0.950 rows=20 loops=1)
   Buffers: shared hit=122
   ->  Sort (actual time=0.945..0.947 rows=20 loops=1)
         Sort Key: total_assets_thousands DESC
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=122
         ->  Index Scan using idx_fact_bank_quarter_date on fact_bank_quarter (actual time=0.010..0.549 rows=4257 loops=1)
               Index Cond: (quarter_end_date = '2026-06-30'::date)
               Buffers: shared hit=122
 Planning:
   Buffers: shared hit=12
 Planning Time: 0.110 ms
 Execution Time: 0.962 ms
```

**AFTER composite index on `(quarter_end_date, total_assets_thousands DESC)`**:

```
 Limit (actual time=0.043..0.063 rows=20 loops=1)
   Buffers: shared hit=19 read=3
   ->  Index Scan using fact_bank_quarter_assets_sort on fact_bank_quarter (actual time=0.042..0.060 rows=20 loops=1)
         Index Cond: (quarter_end_date = '2026-06-30'::date)
         Buffers: shared hit=19 read=3
 Planning:
   Buffers: shared hit=12
 Planning Time: 0.115 ms
 Execution Time: 0.076 ms
```

**What each plan is doing.** The no-index plan uses `idx_fact_bank_quarter_date` to find the 4,257 rows for 2026-06-30, then a top-N heapsort picks the 20 largest. The single-column plan is **identical to the BEFORE plan**: `Index Scan using idx_fact_bank_quarter_date` plus a top-N heapsort. The planner did not use `fact_bank_quarter_assets_sort` at all. Walking the single-column index in descending order and filtering by quarter, which is what the planner *could* have done, would cost more than reading the 4,257 quarter rows through `idx_fact_bank_quarter_date` and sorting them in memory. The single-column index is not earning its keep - it is being ignored. The composite plan reads the 20 rows directly from the index with no filter and no sort, and is 13× faster than no index.

**Why both are removed anyway.** The report is Power BI in **Import mode**. It pulls the mart into VertiPaq during refresh and answers every visual from memory, so the PostgreSQL index is only relevant during that refresh. The refresh loads the whole fact table for a star schema; it is a full-table scan, not a per-quarter top-N query. The demo above exercises the shape of a DirectQuery report, which this one is not. On a full-table refresh the index does not help, and after the refresh it is never consulted again.

Even setting the refresh path aside, the DirectQuery-shape query in the demo already returns in about 1 ms with no index at all. An index that improves a sub-millisecond query to a sub-tenth-of-a-millisecond query, on a table loaded once per quarter, is write and vacuum cost for a latency win that would not be felt even if the report were DirectQuery. The composite shape is what a DBA would build if this table were serving thousands of these queries per second in a DirectQuery report, or if the query were run across many quarters at once. Neither is true here.

The single-column shape is worse than useless in the long run: the planner already ignores it today, so keeping it would be pure write and vacuum cost for an index that no query uses. The composite shape is strictly better than it anyway, and even the composite is not worth keeping for a query this fast.

This is the "tried it and could not show it being used" case, and the plan output backs that up: the single-column index is not used at all. The composite index *is* used, but it is still removed because Import mode answers the report from VertiPaq and the refresh is a full-table scan. On both grounds, keeping either shape would be write and vacuum cost for no benefit. That distinction is documented here because it is the kind of judgment call this `EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)` exercise yields.

### 1.6 Why `VACUUM ANALYZE` sits in every demo

`CREATE INDEX` is like adding an index to the back of a book. The index says "JPMorgan Chase - page 412, page 419, page 431." It is complete and correct as far as the values go.

`Index Only Scan` is the planner saying "I trust the index. I will not flip to page 412 to check whether the entry is still valid; I will answer from the index alone." That works only if the index is verified - if the page numbers are known to be current, not stale from an earlier edit. PostgreSQL tracks that verification in the visibility map: one bit per data page, set when `VACUUM` has confirmed that every row on the page is visible to everyone.

`CREATE INDEX` does not set the visibility map. It builds the index and stops. Until `VACUUM` runs, PostgreSQL does not know whether the index entries still point to the current version of a row or to one that has since been updated. So it falls back to the safe path: use the index to find candidate rows, then flip to each data page to confirm. That is `Index Scan`, not `Index Only Scan`. It touches the heap on every row.

In Demos 1 and 3 the query shape is designed so that, once the visibility map is clean, the heap is never touched: the index alone answers the query. But the demo cannot show that unless `VACUUM ANALYZE` runs between `CREATE INDEX` and the second `EXPLAIN`. Without the `VACUUM`, the "after" plan is still an `Index Scan` - the index exists, but trust in it does not.

`VACUUM ANALYZE` is not a measurement cleaning step. It is a physical state change: it writes bits into a file on disk (the visibility map) and refreshes the planner's statistics. Both are preconditions for the plan shape these demos are designed to demonstrate. Omitting the `VACUUM` and then wondering why the index "does not work" is the classic mistake.

The build itself (`run_all_sql.sql` STEP 4) runs `VACUUM ANALYZE` on every table to establish this same state after a load. The demo file runs its own `VACUUM ANALYZE` after each `CREATE INDEX` because a newly created index starts with a stale visibility map. The queries to verify that the build's step ran successfully are in `documentation/post_build_maintenance_checks.md`.

---

## 2. Data Quality

### 2.1 Case-only duplicate company names

Four Consumer Financial Protection 
Bureau (CFPB) company names appear in the source data in two case variants. PostgreSQL's
case-sensitive `TEXT` primary key accepted both forms as distinct rows; Power BI's
case-insensitive collation did not, and the fact-to-dimension relationship from
`fact_complaints.company_name` to `dim_crosswalk.company_name` failed on the
duplicate.

| Lowercased name | Variants in `clean.company_crosswalk` |
|---|---|
| `onemain finance corporation` | `ONEMAIN FINANCE CORPORATION`, `OneMain Finance Corporation` |
| `first technology federal credit union` | two case variants |
| `global credit union` | two case variants |
| `synergy one lending, inc.` | two case variants |

**Fix.** Lowercased `company_name` in `04_clean_complaints.py` and
`05_build_crosswalk.py` so case-only variants collapse into one row. The
lowercase form is the canonical key; Power BI's case-insensitive collation
and PostgreSQL now agree on uniqueness.

**Effect.** `data_mart.dim_crosswalk` dropped from 4,118 to 4,114 rows. The
complaint count is unchanged at 1,077,624 - both variants of each pair
reference the same physical company, so complaints stay attached to the
merged row.

Recorded in `data_quality_summary` as rule `case_fold_to_lower` on
`complaints.company_name`.

### 2.2 Charter class code `MI`

The failures file contains a charter class code that Appendix A does not list.

- **Code:** `MI`
- **Definition:** State-chartered mutual savings bank, supervised by the Federal Deposit Insurance Corporation (FDIC).
- **Status:** Retired.
- **Historical usage:** 14 failure and assistance records from 1938 to 1983.
- **Current classification:** The same institutions are coded `SI` in the
  institutions file today.

Rather than hard-code Appendix A, `data_warehouse.charter_class` is built from
the codes actually present in `clean.institutions` and `clean.failures`. Descriptions
come from a small reference map. A code that appears in the data but not in the
map fails the insert with a NULL-description error that names the code, forcing
an explicit decision rather than a silent miss. The lookup matches the data, not the published
list.

### 2.3 Charter class code `CU`

Appendix A lists `CU` (credit union) as a valid charter class, but no institution
or failure record in the FDIC data carries it. This is expected: the FDIC does
not insure credit unions - they are covered by the National Credit Union
Administration (NCUA) and appear in a separate directory. The
`data_warehouse.charter_class` lookup does not include `CU` because the
derivation sources codes from the data, not from Appendix A. If a future
refresh introduces a credit union, the derivation will fail loudly on the
missing description.

### 2.4 Two directions of divergence

Taken together, the two charter class discrepancies show the published
definitions and the data disagree in both directions: the data uses one code
Appendix A omits (`MI`), and omits one code Appendix A lists (`CU`). The lookup
follows the data. Both divergences are recorded in `data_quality_summary`.

### 2.5 Empty `BKCLASS` on CERT 15656

One institution, CERT 15656, has an empty `BKCLASS` field in
`fdic_institutions.json`. It is converted to NULL in `01_clean_institutions.py`
by `trimmed_or_null_if_whitespace` and lands in `data_warehouse.institutions`
with `charter_class_code IS NULL`. 

The column is explicitly defined as nullable in `03_create_institutions.sql`
(`charter_class_code TEXT REFERENCES data_warehouse.charter_class`). Standard
SQL behavior for foreign keys dictates that the constraint only fires when the
value is non-NULL; a NULL value is treated as "unknown" and is permitted
through. The row is retained because excluding it would lose the institution
from the directory, and imputing a fake charter class (e.g., defaulting it to
`N`) would fabricate a classification that the source data does not support.
The same NULL is carried forward into `dim_bank`, meaning the Bank Scorecard
filters show this single institution under `(Blank)` if no specific charter
class is selected.



### 2.6 Other cleaning decisions worth noting

Full record in `data_quality_summary`. The decisions that most affect what can
be said elsewhere:

- **Income-statement fields are YTD, not quarterly.** `NETINC`, `INTINC`,
  `EINTEXP`, `NONII`, `NONIX`, `ELNATR` accumulate through the calendar year.
  Quarterly values are derived in `02_clean_financials.py` by subtracting the
  prior quarter's YTD within the same bank and year. Where the prior quarter's
  YTD is missing, the quarterly value is NULL, not zero - unknown is not the
  same as "no income." This affects any metric built from quarterly income.
- **Every FDIC dollar amount is in thousands.** Assets, deposits, equity,
  income, and the failure-file fields (`QBFASSET`, `QBFDEP`, `COST`). Figures
  presented in billions are converted explicitly and the unit is stated.
- **`consumer_state_code` and other state columns.** Numeric sentinels (`0`),
  single letters (`N`), and full region names (`UNITED STATES MINOR OUTLYING
  ISLANDS`) are nulled at the source. Only 2-letter uppercase codes enter the
  model.
- **`financials.fdic_certificate_number` has no FK to `institutions`.** 5,294
  CERTs in `clean.financials` are not in the current directory - charters that
  filed Call Reports before being absorbed or closed. Enforcing the FK would
  drop those rows and lose the pre-failure financial history that the failures
  analysis depends on.
- **Complaints crosswalk.** 61.65% of complaints (664,397 of 1,077,624) are
  attributed to an FDIC-insured charter. The unmatched 38.35% is dominated by
  credit bureaus, mortgage servicers, fintechs and credit unions. See
  `documentation/crosswalk_method.md` for the method and the breakdown by
  category.

---

## 3. Power BI Report Measures and Their Sources

The Power BI report reads only from `data_mart`. The measures it uses are defined
once and documented here so the same number appears on every page.

### 3.1 Definitions used across pages

| Term | DAX measure | Source |
|---|---|---|
| Complaints | `COUNTROWS(fact_complaints)` | one row per complaint |
| Timely response rate | `DIVIDE(CALCULATE([Complaints], fact_complaints[is_timely_response]=TRUE()), [Complaints])` | CFPB `Timely response?` |
| Monetary relief rate | share where `company_response_to_consumer = "Closed with monetary relief"` | CFPB response column |
| Matched share | `DIVIDE(CALCULATE([Complaints], dim_crosswalk[match_method] <> "unmatched"), [Complaints])` | crosswalk method |
| Banks reporting | distinct CERTs with a row in `fact_bank_quarter` in the latest quarter of the selection | financials |
| Total assets (in billions) | assets of the latest quarter in the selection, converted to billions | balance sheet - a balance, not a flow |
| Net income (in billions) | sum of `net_income_quarterly_thousands` across the selected quarters, converted | derived in `clean.financials` from YTD |
| Median ROA | `MEDIAN(fact_bank_quarter[return_on_assets_percent])` | FDIC annualized ROA |
| Complaints per bn deposits | matched complaints ÷ average of quarter-end deposits across the selected quarters, in billions | Appendix B formula |
| Failures | `COUNTROWS(fact_failures)` | one row per failure event |
| Failure assets (bn) | sum of `total_assets_at_failure_thousands` / 1e6 | failure record |
| Failure loss to insurance fund (bn) | sum of `estimated_loss_to_insurance_fund_thousands` / 1e6 (BLANK if 0 or missing) | failure record |
| Herfindahl-Hirschman Index (HHI) | precomputed per quarter in `fact_concentration` | concentration fact |

### 3.2 Verified against SQL

The Industry page cards were checked against a direct SQL query for 2026 Q2:

- **Banks reporting:** Power BI `4,257`, SQL `4,257`
- **Total assets (bn):** Power BI `26,720`, SQL `26,722.74`

The slight difference in the assets card is display rounding (one decimal vs. two).

---

## 4. Industry Concentration

`fact_concentration` carries three concentration measures per quarter-end,
computed in SQL rather than DAX. The reason is stated in the file: ranking
banks within a quarter and taking the top-10 and top-100 sums requires a full
bank × quarter materialization that exceeded Power BI's practical DAX memory
budget. Computing once in the mart keeps the report fast.

At 2026 Q2:

- **Top 10 asset share:** `AVERAGE(fact_concentration[top_10_share])` across the quarters in scope.
- **Top 100 asset share:** `AVERAGE(fact_concentration[top_100_share])` across the quarters in scope.
- **HHI:** `AVERAGE(fact_concentration[herfindahl_hirschman_index])`, on the standard 0–10,000 scale.

### 4.1 Bank size bands

The Bank Scorecard ranks banks using size bands rather than a continuous x-axis. The bands are calculated as a DAX column on `dim_bank` (`Bank size band`) rather than in the mart, because they are a presentation choice, not a fundamental business rule; if the thresholds move, only the report changes.

**Why these thresholds?** The thresholds - **\$0.25 bn, \$1 bn, \$10 bn, and \$100 bn** - were chosen by analyzing the actual distribution of bank assets at the latest quarter (2026 Q2) and balancing two competing needs: keeping the bands statistically meaningful and keeping the groups roughly comparable in size.

Before picking the cutoffs, the following percentiles were calculated for bank assets:
- **p25:** $0.17 bn
- **p50 (median):** $0.39 bn
- **p75:** $0.99 bn
- **p90:** $3.07 bn
- **p99:** $67.5 bn
- **max:** $4,091 bn (JPMorgan Chase)

The industry is heavily right-skewed: half the banks are under \$0.39 bn, but the largest is \$4 trillion. If the bands were spaced evenly (e.g., every $100 bn), 90% of the industry would fall into a single first bucket, and the chart would show no variation. 

To prevent this, the bands use **round, power-of-ten boundaries**:
- `< $0.25 bn` captures the smallest institutions (including the p25 mark).
- `$0.25 - $1 bn` captures the next tier, roughly up to the p75 mark.
- `$1 - $10 bn` captures regional banks.
- `$10 - $100 bn` captures the large regionals and trust banks.
- `>= $100 bn` captures the national money-center banks (the top 1%).

**The constraints applied:**
1. **No band can hold more than ~40% of the banks.** If a cut is too high, the first bucket swallows the population and the other bands become empty. 
2. **Every band must hold at least 30 banks.** If a cut is too low, the top bucket might only have 4 or 5 banks, making a median or average calculation for that band statistically fragile.

These constraints produced the following distribution for 2026 Q2:
- `< $0.25 bn`: **1,512 banks** (35.5%)
- `$0.25 - $1 bn`: **1,684 banks** (39.6%)
- `$1 - $10 bn`: **897 banks** (21.1%)
- `$10 - $100 bn`: **132 banks** (3.1%)
- `>= $100 bn`: **32 banks** (0.8%)

The counts sum to 4,257 (the total number of banks reporting in 2026 Q2). The largest band by count holds 39.6% of the population, and the smallest band by count still holds 32 banks, satisfying both constraints.

### 4.2 Two definitions of "a bank"

The report uses two close but not identical definitions of "a bank." The
FDIC's `is_active` flag marks **4,220** charters as open. The "Banks
reporting" measure counts the **4,257** charters that filed a Call Report
in 2026 Q2.

The 44-charter difference is charters that filed their last report and then
closed within the quarter. For measuring the industry at a point in time,
the reporting count is the more honest one as it reflects banks that were
actually operating and reporting, not banks the FDIC's directory happened
to list as open on the day the directory was snapshotted.

The 0.9% gap is small enough that the choice does not affect any of the
conclusions above. The top-10 share, top-100 share, HHI, and the failure
counts are all computed from `fact_bank_quarter` and `fact_failures`, which
use the reporting definition throughout. If the industry ever shrinks fast
enough that the two counts diverge materially, the `is_active` flag remains
available as a direct filter on `dim_bank`.

---

## 5. Bank Scorecard: complaints-per-deposit falls with size, but not because size matters

At 2026 Q2, ranked by complaints per \$1bn of average deposits at parent level:

| Rank | Parent | Bank | Complaints | Per \$1bn deposits |
|---:|---|---|---:|---:|
| 1 | SOFI TECHNOLOGIES INC | SoFi Bank | 5,264 | 1,086.48 |
| 2 | SYNCHRONY FINANCIAL | Synchrony Bank | 32,983 | 753.96 |
| 3 | BARCLAYS PLC | Barclays Bank Delaware | 12,558 | 741.00 |
| 4 | AMERICAN EXPRESS CO | American Express National Bank | 25,529 | 445.90 |
| 5 | CAPITAL ONE FINANCIAL CORP | Capital One, National Association | 70,314 | 323.00 |
| ... | ... | ... | ... | ... |
| 27 | JPMORGAN CHASE&CO | JPMorgan Chase Bank, National Association | 79,395 | 49.56 |

The ranking is not a size ranking. Every top-ten bank is a consumer-lending
franchise: cards, auto, mortgage, digital consumer banking. Every bank at the
bottom of the visible page is a diversified or wholesale-institution franchise.
JPMorgan Chase is the largest bank in the country by assets and sits near the
bottom of the per-deposit ranking. Synchrony Bank, one-fortieth of JPMorgan's
size, tops it.

Two readings are possible and the data alone cannot distinguish them:

1. **Consumer-facing banks draw more complaints per dollar** because they
   have more consumer relationships per dollar of funding. A dollar deposited
   at Chase may sit in a corporate treasury account that never complains; a
   dollar of Synchrony funding sits behind a cardholder who can and does.

2. **Consumer-facing banks are treated differently by the CFPB**, and the
   complaints-per-deposit rate measures the CFPB's product filter, not the
   bank's behaviour. The CFPB dataset was filtered to deposit, card, mortgage,
   auto and personal-loan products before it reached us. Banks without those
   products don't appear in it at all.

The most likely answer is that both are true and the ratio conflates them.
What the ranking does say is that complaints per deposit is a measure of
**consumer-product intensity**, not a measure of bank health or service
quality. The brief's own warning applies: any claim that "banks are getting
worse" needs to name the product mix, not the size band.

Size bands confirm the same pattern at a different cut. In the `>= \$100 bn`
band the same order repeats: Amex, Capital One, USAA, Ally, Discover at the
top; JPMorgan, Bank of America, Citibank in the middle; State Street and
Bank of New York Mellon at the bottom, near zero. The largest size band does
not contain the biggest complainers; it contains a mix, and the mix is
determined by product, not by size.

---

## 6. Failures: 2023 was not a smaller 2008

The 2023 failure cohort and the 2008–2011 cohort are different in kind, not just
in size. Quantity and dollars point in opposite directions.

| Period | Failures | Assets at failure (\$bn) |
|---|---:|---:|
| 2008 | 30 | 1,678.0 |
| 2009 | 148 | 2,087.2 |
| 2010 | 157 | 92.1 |
| 2011 | 92 | 34.9 |
| **2008–2011** | **427** | **3,892.2** |
| 2023 | 5 | 532.0 |

Five banks failed in 2023. Three were among the largest failures in US history
- Silicon Valley Bank, Signature Bank and First Republic - and two were small
community banks (Heartland Tri-State Bank, Citizens Bank). The three large
failures held \$532 bn in assets, about one-seventh of the \$3,892 bn held by
the 427 banks that failed across the entire 2008–2011 crisis.

| Bank | Failure date | Assets (\$bn) | Loss to fund (\$bn) |
|---|---|---:|---:|
| Silicon Valley Bank | 2023-03-10 | 209.0 | 18.7 |
| Signature Bank | 2023-03-12 | 110.4 | (not finalised) |
| First Republic Bank | 2023-05-01 | 212.6 | 15.5 |
| Heartland Tri-State Bank | 2023-07-28 | 0.14 | 0.04 |
| Citizens Bank | 2023-11-03 | 0.06 | 0.01 |

Signature Bank's loss is stored as \$0.0 bn in the FDIC's `COST` field. The
report shows it as blank rather than zero so a reader does not read it as "no
loss" - the estimate has not been finalised by the FDIC.

The two small failures (Heartland Tri-State, Citizens Bank) were community banks
under \$150m in assets. Combined they held \$0.20 bn - 0.04% of the \$532 bn held
by the three large failures. The 2023 cohort is a distribution with a very heavy
tail: three enormous failures and two negligible ones, with nothing in between.

### 6.1 What 2009 teaches that 2008 does not

The instinct is to treat 2008 as the crisis year, because Washington Mutual -
the largest bank failure in US history at \$307 bn - failed on 25 September 2008.
But 2009 was larger by assets: 148 failures totalling \$2,087 bn, driven by large
institutions in Florida, Georgia and California. 2010 had the highest *count* of
failures (157) but only \$92 bn in assets. 2011 had 92 failures and \$35 bn.

The pattern is a staggered unwinding: large institutions failed first, in
2008–2009, then a long tail of small and mid-sized banks ran through 2010 - 2012
as real estate and construction loan losses worked through their books. Anyone
reading only the 2008 bar would miss the majority of the failures by count.

### 6.2 The 1930s peak

The failure history in `fact_failures` begins in 1934, at the tail end of the
Great Depression banking crisis. Between 1930 and 1933, roughly 9,000 banks
failed in the United States. The 1934 bar in the "Failures per year" chart
captures the residual failures of that contraction, not a data artifact. The
chart's first bar is not the beginning of the crisis - it is the first year
the FDIC database records.

On the assets-per-year chart the 1930s are invisible: those were thousands of
small failures. The count chart and the assets chart tell different stories
about the same period.

### 6.3 Multi-charter holding companies of the late 1980s

The late-1980s failures include several multi-charter holding companies whose
subsidiaries were all closed on the same day. `FIRST REPUBLICBANK CORP` alone
accounts for 40 failure events on 1988-07-29. Counting failures by event
overstates the number of distinct banking organisations that failed; counting
by holding company would give a lower number for that decade. This is a
structural pattern in the FDIC's data, not a data quality defect. The 2023
failures do not share it - each is a single independent institution.

---

## 7. Directed Analysis

### 7.1 Q1 - Data quality

The complete, authoritative record of data quality is the `data_quality_summary`
table, which contains 147 rows. It has two parts:
1.  **Column profiles (rows 1-103):** Shows the final state of the clean data (row count, null count, distinct count for every column).
2.  **Rule rows (rows 104-147):** Documents every specific cleaning decision, how many rows it touched, and what action was taken (e.g., `nulled`, `harmonized`).

The query to view the full table is in `sql/03_directed_analysis/01_data_quality_summary.sql`.

This section pulls out the most important findings that affect the downstream analysis.

#### 7.1.1 Summary of data quality rules applied

The table below lists every rule that materially changed the data. (It omits the column profile rows, which show columns that were left untouched). The full record, including the 103 profile rows, is in `data_quality_summary`.

| Table | Column | Rule                  | Rows affected | Action |
|---|---|-----------------------|---:|---|
| institutions | end_date | placeholder date      | 4,242 | NULLed |
| institutions | holding_company_name | blank/whitespace      | 10,760 | NULLed |
| institutions | website_address | blank/whitespace      | 23,686 | NULLed |
| institutions | total_assets_thousands | absent value          | 4,006 | NULLed |
| institutions | total_deposits_thousands | absent value          | 4,006 | NULLed |
| institutions | charter_class_code | blank BKCLASS         | 1 | NULLed |
| financials | total_equity_thousands | blank EQ              | 1,394 | NULLed |
| financials | net_income_quarterly_thousands | prior quarter missing | 469 | NULLed |
| financials | interest_income_quarterly_thousands | prior quarter missing | 469 | NULLed |
| financials | interest_expense_quarterly_thousands | prior quarter missing | 469 | NULLed |
| financials | noninterest_income_quarterly_thousands | prior quarter missing | 469 | NULLed |
| financials | noninterest_expense_quarterly_thousands | prior quarter missing | 469 | NULLed |
| financials | provision_for_credit_losses_quarterly_thousands | prior quarter missing | 469 | NULLed |
| failures | fdic_certificate_number | blank CERT            | 488 | NULLed |
| failures | acquiring_state_code | invalid state code    | 813 | NULLed |
| failures | total_assets_at_failure_thousands | text to integer       | 154 | NULLed |
| failures | total_deposits_at_failure_thousands | text to integer       | 2 | NULLed |
| complaints | consumer_state_code | invalid state code    | 14,868 | NULLed |
| complaints | company_public_response | blank/whitespace      | 575,356 | NULLed |
| complaints | consumer_tags | blank/whitespace      | 881,499 | NULLed |
| complaints | sub_issue | blank/whitespace      | 162,449 | NULLed |
| complaints | sub_product | blank/whitespace      | 111 | NULLed |
| complaints | issue | blank/whitespace      | 5 | NULLed |
| complaints | consumer_zip_code | blank/whitespace      | 373 | NULLed |
| complaints | company_name | case fold*            | 1,077,624 | Lowercased |
| complaints | harmonized_product | label collapse        | 190,028 | Harmonized |

***Note on case folding:** The `company_name` case fold rule was applied to all 
1,077,624 rows to ensure that Power BI's case insensitive collation could 
successfully join the fact table to the dimension table. Without this rule, 
four companies that appeared in the raw CFPB data with two different casing 
variants (e.g., `OneMain Finance Corporation` and `ONEMAIN FINANCE CORPORATION`) 
would have caused a many-to-one relationship error in Power BI. Applying 
`.lower()` to the entire column during the Python load step guaranteed 
uniqueness and a clean join.

#### 7.1.2 Types of missingness

The dataset contains three distinct kinds of missing value, and treating them
as one thing would mislead.

**Structural missingness.** Columns that are null because the concept does not
apply to that row. `institutions.end_date` is null on 4,242 rows because the
bank is still open and the FDIC's placeholder `12/31/9999` is nulled in the
cleaner. `institutions.holding_company_name` is null on 10,760 rows (38.66%)
because the charter has no parent. `institutions.website_address` is null on
23,686 rows (85.09%) because the FDIC does not publish a website for most
closed institutions. None of these is a defect - the null is the correct
representation.

**Structural nulls in the failure file.** `failures.uninsured_deposits_at_failure_thousands`
is null on 3,950 of 4,117 rows (95.94%). The column only has a value for very
recent failures where the FDIC publishes an estimate; for pre-2000 failures it
was never recorded. `failures.fdic_certificate_number` is null on 488 rows
(11.85%) because pre-1934 failures and assistance transactions sometimes lack a
charter reference. A name-matching recovery pass against
`institutions.institution_name` was evaluated and rejected: 106 of the 488
match an exact modern name, but every one of them is a pre-1976 failure whose
name collides with a modern charter of the same name (for example, multiple
1936 records called "First State Bank" match a modern charter of that name).
The match would be coincidental, not evidence of identity, and would fabricate
a link between unrelated entities. A NULL CERT is the honest representation.
`failures.resolution_date` is null on 583 rows (14.16%) for a similar reason.
These are legitimate gaps in the historical record, not cleanup failures.

**Optional field missingness.** The CFPB does not require companies to publish
a public response, and `complaints.company_public_response` is null on
575,356 rows (53.39%) for that reason. `complaints.consumer_tags` is null on
881,499 rows (81.80%) - tags only apply to complaints from older Americans or
servicemembers. `complaints.sub_issue` is null on 162,449 rows (15.07%) because
the CFPB does not categorise every issue to the sub-issue level. None of these
are data defects.

#### 7.1.3 Rules that materially changed the data

Three cleaning rules moved more than 100,000 rows:

- **`consumer_tags` blank → null** (881,499 rows). The raw CFPB file writes an
  empty string when no tag applies; the cleaner converts those to NULL.
- **`company_public_response` blank → null** (575,356 rows). Same pattern.
- **`harmonized_product` label collapse** (190,028 rows). The August 2023 CFPB
  relabel renamed several products; the cleaner maps both eras to a single
  canonical name.

Two of these - the product harmonization and the blank-to-null treatment of
optional text - are behavioral choices that change how the report reads.
Without the harmonization, every product that was renamed would appear twice on
the Complaints page. Without the blank-to-null conversion, a reader of
`company_public_response` would see thousands of empty strings rather than
missing values.

#### 7.1.4 Invalid values that were nulled

- **`complaints.consumer_state_code`** (14,868 rows). Numeric sentinels (`0`),
  single letters (`N`), and full region names
  (`UNITED STATES MINOR OUTLYING ISLANDS`) are nulled. Only two-letter US state
  codes enter the model.
- **`failures.acquiring_state_code`** (813 rows). Same treatment; 812 of these
  are the numeric sentinel `0 ` (with trailing space).
- **`institutions.charter_class_code`** (1 row). CERT 15656 has a blank
  `BKCLASS`; the cleaner nulls it and the row is retained.
- **`institutions.federal_reserve_rssd_id`** (0 rows reported, but rule fires).
  The FDIC sentinel `FED_RSSD = 0` is nulled.

The row counts are small relative to the file sizes, but each is a value that
would have silently corrupted a group-by or a map visual had it not been
nulled.

#### 7.1.5 Published definitions that disagree with the data

Two discrepancies were identified by comparing the file contents against
Appendix A:

1. **The failures file uses a charter class code that Appendix A omits.**
   `MI` (state-chartered mutual savings bank, supervised by the FDIC, retired)
   appears on 14 failure records from 1938 to 1983. The same charters are coded
   `SI` in the current institutions file. The `charter_class` lookup is built
   from the codes actually present in the data, so `MI` is in the lookup and
   the FK resolves.

2. **Appendix A lists a code the data does not use.** `CU` (credit union)
   does not appear in either `clean.institutions` or `clean.failures`. The
   FDIC does not insure credit unions; they are covered by the NCUA. The
   lookup derived from the data does not include `CU`.

Both discrepancies are recorded in `data_quality_summary` under the rule
`data_vs_published_definitions`.

#### 7.1.6 What changed as a result

The failures of these rules are the values that never made it into the model
in their original form:

- 4,242 failure records that carry the FDIC placeholder date `12/31/9999` are
  now NULL in `end_date` instead of fictional far future date.
- The `consumer_state_code` group-by on the Complaints page excludes 14,868
  complaints whose state was blank or non-US. Those complaints appear in the
  totals but not in any state level breakdown.
- `holding_company_name` group-by on the Bank Scorecard excludes 10,760
  charters (38.66% of the directory). These are the charters that file without
  a registered parent; the scorecard's parent-level view does not show them.
  The Industry page's "Banks reporting" measure counts all reporting charters
  regardless, so the two numbers are consistent - one is charter level, the
  other parent-level.

Every one of these decisions is queryable from `data_quality_summary`. Anyone
who wants to know what happened to a specific value, and how many rows it
touched, can find the answer there without reading the Python or SQL.

### 7.2 Q2 - Crosswalk

61.65% of complaints (664,397 of 1,077,624) are attributable to an FDIC-insured
charter. By method:

| Match method      | Companies | Complaints | Share  |
|-------------------|----------:|-----------:|-------:|
| exact             |       150 |    481,867 | 44.72% |
| manual_override   |        13 |    176,718 | 16.40% |
| suffix_stripped   |         4 |      5,812 |  0.54% |
| **matched**       |   **167** |**664,397** |**61.65%**|
| unmatched         |     3,947 |    413,227 | 38.35% |

The unmatched remainder is dominated by companies that are not banks:

| Company category       | Companies | Complaints | Share of unmatched |
|------------------------|----------:|-----------:|-------------------:|
| unknown                |     2,938 |    137,385 |             33.25% |
| mortgage_servicer      |       559 |     83,645 |             20.24% |
| credit_bureau          |         3 |     60,747 |             14.70% |
| fintech_or_payments    |        18 |     49,710 |             12.03% |
| credit_union           |        24 |     39,094 |              9.46% |
| auto_finance           |        30 |     23,065 |              5.58% |
| other_lender           |       340 |     15,802 |              3.82% |
| bank_named_unmatched   |        35 |      3,779 |              0.91% |

Three categories - mortgage servicers, credit bureaus and fintechs - account
for roughly 47% of unmatched complaints. These are not banks, and the CFPB
database is not the right lens for comparing their behaviour against banks.

The interpretation matters for anything that ranks or compares banks on
complaints. If a reader sees "Bank X received 70,000 complaints" they need to
know that the same database also contains 60,000 complaints against Equifax
alone - and that Equifax is not a bank. The crosswalk is the mechanism that
separates the two populations; the 38.35% unmatched share is the size of the
population the report is not comparing.

Method: `documentation/crosswalk_method.md`.
Queries: `sql/03_directed_analysis/02_crosswalk_coverage.sql`.

### 7.3 Q3 - Consolidation

The brief asks three things: how many banks report each year from 2008 to 2026,
what share of industry assets the largest 10 and largest 100 hold at the start
and end of the window, and whether the fall in bank count comes from failures
or mergers.

#### 7.3.1 Bank count and concentration

| Year | Avg banks reporting | Top 10 asset share | Top 100 asset share | HHI |
|---|---:|---:|---:|---:|
| 2008 | 8,419 | 47.12% | 76.45% | 387 |
| 2016 | 6,031 | 51.70% | 80.76% | 459 |
| 2026 | 4,278 | 53.68% | 82.92% | 491 |

The bank count fell by 49.2% over eighteen years, from 8,419 to 4,278. The
average count within a year is used because `fact_concentration` reports at
quarter grain.

Concentration rose modestly in the same window. The top 10 banks held 47.1% of
industry assets in 2008 and 53.7% in 2026, a 6.6-point increase. The top 100
rose from 76.5% to 82.9%, a 6.4-point increase. The Herfindahl-Hirschman Index
rose from 387 to 491, still well under the 1,500 threshold below which the US
Department of Justice considers a market unconcentrated.

Two things stand out. First, the top-100 share moved almost exactly as much as
the top-10 share. This is not a story about the largest banks taking over; it
is a story about the largest 100 banks absorbing the rest of the industry while
the top 10 moved marginally ahead of the pack. The middle of the industry - the
banks between roughly 100th and 500th by size - is emptying out.

Second, the concentration increase is modest by the standard measure. An HHI
of 491 is very low. The US banking industry is legally unconcentrated by the
DOJ threshold even after eighteen years of consolidation. What changed is not
that a few banks dominate the market; it is that most of the very small banks
stopped existing.

#### 7.3.2 Failure or merger

| Test | Value |
|---|---:|
| Net decline in bank count, 2008 Q1 to 2026 Q2 | 4,247 |
| Total failures 2008–2026 | 562 |
| Failures as a share of net decline | 13.2% |

Seven of every eight charters that stopped reporting financials between 2008
and 2026 did so without failing. They were acquired, merged, or closed
voluntarily. The FDIC's data has no merger file, so this is inferred from the
absence of a failure record for the CERT: if a charter appears in
`fact_bank_quarter` in quarter Q but not in Q+4, and has no matching row in
`fact_failures`, it left the industry by merger or voluntary closure rather
than by failure.

The 562 failures themselves follow a distinct pattern over the same period:

| Year | Failures |
|---|---:|
| 2008 | 30 |
| 2009 | 148 |
| 2010 | 157 |
| 2011 | 92 |
| 2012 | 51 |
| 2013 | 24 |
| 2014 | 18 |
| 2015 | 8 |
| 2016 | 5 |
| 2017 | 8 |
| 2018 | 0 |
| 2019 | 4 |
| 2020 | 4 |
| 2021 | 0 |
| 2022 | 0 |
| 2023 | 5 |
| 2024 | 2 |
| 2025 | 2 |
| 2026 | 4 |

Failures were concentrated in 2008–2013 (502 of 562, 89%), dropped to near
zero through the late 2010s, and re-emerged in 2023 with three large banks
and two small ones. The 2023 spike contributes 5 events, not enough to
register against the merger-driven decline.

#### 7.3.3 Consolidation conclusion

**The fall in bank count comes overwhelmingly from mergers, not failures.**
Failures account for 13.2% of the disappearance. The remaining 86.8% is
mergers and voluntary closures, which the FDIC does not record as events in
any file this dataset contains.

The two trends - a halving of the bank count and a modest 6.6-point rise in
top-10 concentration - are consistent with each other but tell different
stories. The industry is not becoming a monopoly; it is shrinking from the
bottom, with the very small banks absorbed into larger ones and the top 100
slowly taking a larger share of a slower-growing asset base.

Queries: `sql/03_directed_analysis/03_consolidation.sql`.

---

## 8. Open-Ended Analysis

### 8.1 Part 6 | Required: The complaint boom = three patterns, not one

The CFPB complaint volume grew from 80,060 in 2019 to 232,776 in 2025 - a 191%
increase. The count of distinct companies complained about grew from 1,340 to
1,973 - a 47% increase. Complaints per company rose from 59.7 to 118.0 - a 98%
increase.

The three rates are not equal. Complaints grew four times faster than the
population of companies. If the CFPB's growth were purely a matter of more
consumers knowing about the CFPB, the count of companies should have grown at
the same rate as the complaints; it did not. If it were purely a matter of
complaints concentrating in a few companies, the count of companies should
have stayed flat; it did not. The truth is between the two, and the pattern
of where growth is concentrated points at three distinct mechanisms.

#### 8.1.1 Broad-based growth in consumer awareness

Complaints against the largest consumer banks grew 2–3× between 2019 and 2025.
Capital One went from 4,730 to 18,994; JPMorgan Chase from 6,631 to 15,864;
Wells Fargo from 5,759 to 12,764. This is the baseline pattern - rising volume
across the same companies. It is consistent with more consumers knowing the
CFPB exists and using it.

#### 8.1.2 Credit bureaus appear from nowhere

In 2019, Equifax received 92 complaints, TransUnion 73 and Experian 92.
In 2025, they received 8,717, 7,006 and 6,666 respectively. Combined, the
three credit bureaus added 22,132 complaints - more than any bank except
Capital One.

This is not a rise in per-company intensity. The credit bureaus are not
consumer-facing banks and complaints against them do not fit the CFPB's
traditional scope. Their appearance in the data reflects a change in how
consumers use the CFPB: credit-reporting disputes that were previously
handled by the bureaus directly (or by the FTC) now flow through the CFPB.

#### 8.1.3 New companies in the CFPB universe

Chime Financial went from zero CFPB complaints in 2019 to 6,114 in 2025.
Block (formerly Square) went from 92 to 4,281. These are fintechs - companies
that partner with a bank for depository services but are not themselves banks.
Their customers are using the CFPB as a complaint channel that did not exist
for them a few years earlier.

Navy Federal Credit Union went from 856 to 12,678 - the largest relative
increase of any company in the data. Credit unions were virtually invisible in
the CFPB dataset in 2019.

#### 8.1.4 Product-mix evidence

The product mix confirms the decomposition. Between 2019 and 2025:

| Product | 2019 | 2025 | Growth |
|---|---:|---:|---:|
| Credit card | 25,823 | 89,978 | +248% |
| Checking or savings account | 21,734 | 84,195 | +287% |
| Mortgage | 22,700 | 24,697 | +9% |
| Vehicle loan or lease | 5,485 | 20,769 | +279% |
| Payday / title / personal loan | 4,318 | 13,137 | +204% |

Mortgage complaints are flat. Every other product tripled. If the growth were
purely more consumers reporting the same kinds of problems, every product
would rise at similar rates. The flat mortgage line and the steep lines for
cards and deposit accounts say the growth is concentrated in products where
the CFPB has recently become a first-choice channel.

#### 8.1.5 Conclusion

The complaint boom is not one phenomenon. It is three. Consumer awareness
of the CFPB has grown broadly (2–3× across the largest banks). Credit
bureaus have entered the CFPB universe (from near-zero to 22,000 combined
complaints). And fintechs have entered it (Chime and Block from near-zero
to over 10,000 combined). The first is a rise in reporting; the second and
third are a rise in scope.

The practical implication: a report that charts "complaints against banks"
over time is measuring three different things at once. Any comparison between
2019 and 2025 needs to state which companies are in scope and whether the
comparison is like-for-like.

Queries: `sql/04_open_ended_analysis/01_complaint_boom.sql`.

### 8.2 Part 6 | Personal choice: Do banks pay up when the CFPB gets involved?

When the CFPB forwards a complaint to a company, the company can close it in
several ways: with an explanation, with non-monetary relief (like fixing a
report), or with monetary relief (a refund or credit). Monetary relief is the
clearest win for the consumer, and it is the only direct financial consequence
recorded in the complaint database.

Two questions follow. First, do banks and non-banks treat monetary relief
differently? Second, are the banks that draw the most complaints also the ones
most likely to pay?

#### 8.2.1 Overall picture

Across the full 1,077,624 complaints, **11.1%** were closed with monetary
relief. Another 9.7% received non-monetary relief, and the vast majority
(78.7%) were closed with an explanation.

#### 8.2.2 Stark divide: Banks versus non-banks

The crosswalk split the companies into FDIC-insured charters (`matched`) and
everyone else (`unmatched`). The monetary relief rate is drastically different
across the two groups.

| Company type | Complaints | Monetary relief rate |
|---|---:|---:|
| Matched banks | 664,397 | 16.1% |
| Unmatched (non-banks) | 413,227 | 3.1% |

A complaint against an FDIC-insured bank is **five times more likely** to
result in a refund or credit than a complaint against a non-bank. This is the
strongest behavioral difference found in the complaint data. The
unmatched group - dominated by credit bureaus, mortgage servicers, and
fintechs - overwhelmingly closes complaints with an explanation rather than
a payment.

#### 8.2.3 Big banks

If monetary relief is a sign of taking complaints seriously, it could be expected that the banks with the highest complaint volumes are to have the highest relief rates.
The data shows a massive spread among the top 5.

| Bank | Complaints | Monetary relief rate |
|---|---:|---:|
| JPMorgan Chase | 79,395 | 12.4% |
| Wells Fargo | 74,166 | 10.3% |
| Bank of America | 71,391 | 31.8% |
| Capital One | 70,314 | 10.7% |
| Citibank | 61,323 | 24.2% |

The differences are stark. Bank of America issues monetary relief on almost a
third of its complaints (31.8%), while Wells Fargo and Capital One issue it on
just over 10% of theirs. A consumer complaining about Bank of America is
**three times more likely** to receive a refund or credit than a consumer
complaining about Capital One, assuming the underlying issues are comparable.

#### 8.2.4 Conclusion

Monetary relief is not evenly distributed. 

First, there is a structural divide between banks and non-banks: banks are five
times more likely to pay out than the credit bureaus and fintechs that dominate
the unmatched remainder. 

Second, even among the largest banks, the variation is large (from 10% to
32%). This raises a question the data cannot answer: is Bank of America's high
relief rate a sign of better customer service, or a sign that its complaints
are more likely to be about concrete, refundable issues (like a wrong fee)
rather than process issues (like a delayed response)? Without the narrative
text of the complaints, I cannot tell. What the data does show is that a
claim like "banks don't pay when they are wrong" cannot be made uniformly. 

Query: `sql/04_open_ended_analysis/02_monetary_relief.sql`.