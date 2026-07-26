/*
================================================================================
 File    : analyze_statistics.sql
 Purpose : ANALYZE commands and statistics inspection — PostgreSQL's query
           planner relies entirely on these to choose good plans.
 Author  : Shubham Lashkar
================================================================================
*/

-- ============================================================================
-- 1) ANALYZE a single table — refreshes the planner's statistics (row count
--    estimates, most-common values, histogram) without touching dead tuples
-- ============================================================================
ANALYZE orders;

-- ============================================================================
-- 2) ANALYZE the entire database
-- ============================================================================
ANALYZE;

-- ============================================================================
-- 3) Check statistics staleness across all tables
-- ============================================================================
SELECT
    schemaname, relname,
    n_mod_since_analyze,
    last_analyze, last_autoanalyze
FROM pg_stat_user_tables
WHERE n_mod_since_analyze > 0
ORDER BY n_mod_since_analyze DESC
LIMIT 20;

-- ============================================================================
-- 4) Inspect the actual stored statistics for a column — this is what the
--    planner looks at when estimating selectivity
-- ============================================================================
SELECT
    attname,
    n_distinct,
    most_common_vals,
    most_common_freqs,
    correlation
FROM pg_stats
WHERE tablename = 'orders' AND attname = 'order_status';

-- ============================================================================
-- 5) Increase statistics target for a column with skewed distribution
--    (default target is 100 buckets — too coarse for highly skewed columns
--    where the planner needs finer-grained most-common-value tracking)
-- ============================================================================
ALTER TABLE orders ALTER COLUMN order_status SET STATISTICS 500;
ANALYZE orders;

-- ============================================================================
-- 6) Compare estimated vs actual row counts for a query — the primary way
--    to detect that stale/insufficient statistics are causing a bad plan
-- ============================================================================
EXPLAIN ANALYZE
SELECT * FROM orders WHERE order_status = 'Pending' AND order_date >= CURRENT_DATE - 7;
-- Look at "rows=" (estimate) in the EXPLAIN line vs "actual rows=" —
-- a large mismatch (>10x) usually means stats are stale or the statistics
-- target is too low for this column's distribution
