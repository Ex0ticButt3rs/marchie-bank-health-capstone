# Post-Build Maintenance Checks

The build in `sql/run_all_sql.sql` ends with a `VACUUM ANALYZE` (STEP 4) that runs on every table in `data_warehouse` and `data_mart`. This document describes three queries that verify the two halves of that step actually ran.

- **`VACUUM`** updates the visibility map, which allows `Index Only Scan` to skip the heap. Without it, the planner still chooses `Index Only Scan`, but `Heap Fetches` is large and the query does almost as much work as an `Index Scan`.
- **`ANALYZE`** refreshes the planner's statistics, which allows the first query after a build to plan against the real row counts.

Each check returns either zero rows or a value that should be uniform. Anything else means the maintenance step did not run or did not complete.

## Table of Contents

1. [Visibility Map is Clean](#1-visibility-map-is-clean)
2. [Statistics Exist for Every Column](#2-statistics-exist-for-every-column)
3. [Statistics are Recent](#3-statistics-are-recent)
4. [Cross-Reference](#4-cross-reference)

---

## 1. Visibility Map is Clean

Every page in every table in `data_warehouse` and `data_mart` should be all-visible. `pct_visible` should be 100.

```sql
SELECT relname, relpages, relallvisible, ROUND(100.0 * relallvisible / NULLIF(relpages, 0), 2) AS pct_visible
FROM pg_class
WHERE relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname IN ('data_warehouse', 'data_mart')) AND relkind = 'r'
ORDER BY relname;
```

### 1.1 What the query reads

The query reads two system catalogs: `pg_class` (one row per table, index, sequence, view) and `pg_namespace` (one row per schema). It selects columns from both and computes one derived column.

**`pg_class` columns selected:**

- **`relname`** - the name of the table, index, or other object.
- **`relpages`** - the number of 8 kB pages the table's heap file occupies on disk.
- **`relallvisible`** - the number of pages that are marked "all-visible" in the visibility map. A page is all-visible when `VACUUM` has confirmed that every row on it is visible to every transaction.

**`pg_class` columns used only in the `WHERE` clause:**

- **`relnamespace`** - the OID of the schema this object lives in.
- **`relkind`** - the kind of object. `'r'` means "ordinary table".

**`pg_namespace` columns used:**

- **`oid`** - the schema's object identifier.
- **`nspname`** - the schema's name.

The sample run shows every table at 100.00 as expected.

### 1.3 What to do if a row is below 100

The `VACUUM` half of STEP 4 did not run on that table, or it ran before the table was fully populated. Check the build log for `=== END: VACUUM ANALYZE ===`. If missing, re-run the `\gexec` block from `run_all_sql.sql` STEP 4.

---

## 2. Statistics Exist for Every Column

`ANALYZE` populates the `pg_stats` view. A column with no row in `pg_stats` has never been analyzed. This query returns the columns that are missing statistics. A clean build returns zero rows.

```sql
SELECT t.schemaname, t.tablename, c.column_name
FROM pg_tables t
JOIN information_schema.columns c
  ON c.table_schema = t.schemaname AND c.table_name = t.tablename
LEFT JOIN pg_stats s
  ON s.schemaname = t.schemaname AND s.tablename  = t.tablename AND s.attname = c.column_name
WHERE t.schemaname IN ('data_warehouse', 'data_mart') AND s.attname IS NULL
ORDER BY t.schemaname, t.tablename, c.column_name;
```

### 2.1 What the query reads

- **`pg_tables`** - one row per table. Used to get the list of tables in the two schemas.
- **`information_schema.columns`** - one row per column. Used to get the list of columns in each table.
- **`pg_stats`** - one row per column that `ANALYZE` has seen. A `LEFT JOIN` against this view reveals columns that have no statistics row.

### 2.2 What the output columns mean

| Column | Meaning |
|---|---|
| `schemaname` | The schema the table lives in. |
| `tablename` | The table's name. |
| `column_name` | The column with no statistics. |

An empty result means every column has statistics.

### 2.3 What to do if a row is returned

The `ANALYZE` half of STEP 4 did not run on those tables. Re-run `ANALYZE <schema>.<table>;` for each table and re-check.

---

## 3. Statistics are Recent

`pg_stat_user_tables` records when each table was last analyzed. After a build, `last_stats_refresh` should be within the last few minutes.

```sql
SELECT schemaname, relname, last_analyze, last_autoanalyze, COALESCE(last_analyze, last_autoanalyze) AS last_stats_refresh
FROM pg_stat_user_tables
WHERE schemaname IN ('data_warehouse', 'data_mart')
ORDER BY schemaname, relname;
```

### 3.1 What the query reads

`pg_stat_user_tables` is a statistics-collector view. It has one row per user table, with counters and timestamps for maintenance operations.

### 3.2 What the output columns mean

| Column | Meaning |
|---|---|
| `schemaname` | The schema the table lives in. |
| `relname` | The table's name. |
| `last_analyze` | Timestamp of the last manual `ANALYZE`. |
| `last_autoanalyze` | Timestamp of the last autovacuum's `ANALYZE`. |
| `last_stats_refresh` | Whichever of the two is more recent. Should be within the current build. |

If any row shows `NULL` for `last_stats_refresh`, that table has never been analyzed.

### 3.3 What to do if a row shows NULL or a stale timestamp

If a row is `NULL`, the table was never analyzed. If the timestamp is from before the last `docker compose down -v`, the `ANALYZE` was on a previous build. Re-run `ANALYZE <schema>.<table>;` for each table and re-check. If the issue persists after a few seconds, check the build log to see if the `\gexec` block failed.

---

## 4. Cross-Reference

The `VACUUM ANALYZE` at STEP 4 exists for two reasons, both explained in `findings.md` §1.6 and in the `run_all_sql.sql` header:

1. To update the visibility map, verified by §1.
2. To refresh the planner's statistics, verified by §2 and §3.

§2 and §3 catch different failure modes. §2 catches "stats were never computed." §3 catches "stats were computed, but on a different build." Running both is the only way to be sure the statistics reflect the current data.