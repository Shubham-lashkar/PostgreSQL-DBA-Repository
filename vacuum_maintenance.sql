/*
================================================================================
 File    : vacuum_maintenance.sql
 Purpose : VACUUM commands and the MVCC/bloat problem they solve.
 Author  : Shubham Lashkar
================================================================================
*/

-- ============================================================================
-- Why VACUUM is needed: PostgreSQL's MVCC model
-- ============================================================================
-- PostgreSQL never overwrites a row in place on UPDATE/DELETE — it marks the
-- old row version as "dead" and writes a new version. Dead rows are not
-- physically removed until VACUUM runs. Without regular vacuuming, tables
-- and indexes bloat with dead tuples, wasting disk space and slowing scans.

-- ============================================================================
-- 1) Standard VACUUM — reclaims space for reuse WITHIN the table, does not
--    return space to the OS, does not require an exclusive lock (safe to run
--    on a live production table)
-- ============================================================================
VACUUM orders;

-- Verbose output shows exactly what was reclaimed
VACUUM VERBOSE orders;

-- ============================================================================
-- 2) VACUUM FULL — rewrites the entire table to a new file, returns space to
--    the OS. Requires an ACCESS EXCLUSIVE lock — blocks ALL access to the
--    table for the duration. Use only during maintenance windows, never
--    routinely on a live production table.
-- ============================================================================
VACUUM FULL orders;

-- ============================================================================
-- 3) VACUUM ANALYZE — combines dead-tuple cleanup with statistics refresh in
--    one pass (see Analyze/ for why fresh statistics matter)
-- ============================================================================
VACUUM ANALYZE orders;

-- ============================================================================
-- 4) Check table bloat / dead tuple count before deciding whether VACUUM is
--    needed and how urgent it is
-- ============================================================================
SELECT
    schemaname, relname,
    n_live_tup, n_dead_tup,
    ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_pct,
    last_vacuum, last_autovacuum
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC
LIMIT 20;

-- ============================================================================
-- 5) Transaction ID wraparound check — PostgreSQL MUST vacuum before the
--    transaction counter wraps around (catastrophic if it happens
--    uncontrolled); this shows how close each table is to forcing an
--    emergency autovacuum
-- ============================================================================
SELECT
    relname,
    age(relfrozenxid) AS xid_age,
    2000000000 - age(relfrozenxid) AS xids_remaining_before_forced_vacuum
FROM pg_class
WHERE relkind = 'r'
ORDER BY age(relfrozenxid) DESC
LIMIT 20;

-- ============================================================================
-- 6) Per-table autovacuum tuning (aggressive vacuum for a high-churn table)
--    Default thresholds (20% of table + 50 rows) are too conservative for
--    tables with very high update/delete rates.
-- ============================================================================
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.05,   -- vacuum after 5% dead tuples instead of default 20%
    autovacuum_vacuum_threshold = 1000,
    autovacuum_analyze_scale_factor = 0.02
);
