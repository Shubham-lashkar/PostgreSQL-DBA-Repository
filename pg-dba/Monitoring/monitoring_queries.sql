/*
================================================================================
 File    : monitoring_queries.sql
 Purpose : Day-to-day PostgreSQL health monitoring — connections, locks,
           long-running queries, cache hit ratio, table/index bloat.
 Author  : Shubham Lashkar
================================================================================
*/

-- ============================================================================
-- 1) Currently running queries, longest first
-- ============================================================================
SELECT
    pid, usename, application_name, client_addr,
    state, query_start, NOW() - query_start AS duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- ============================================================================
-- 2) Blocking / blocked query chains
-- ============================================================================
SELECT
    blocked.pid        AS blocked_pid,
    blocked.query      AS blocked_query,
    blocking.pid       AS blocking_pid,
    blocking.query     AS blocking_query
FROM pg_stat_activity blocked
JOIN pg_locks blocked_locks ON blocked_locks.pid = blocked.pid AND NOT blocked_locks.granted
JOIN pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.pid != blocked_locks.pid AND blocking_locks.granted
JOIN pg_stat_activity blocking ON blocking.pid = blocking_locks.pid;

-- ============================================================================
-- 3) Connection count by state and by database — detect connection leaks
--    or approaching max_connections
-- ============================================================================
SELECT datname, state, COUNT(*)
FROM pg_stat_activity
GROUP BY datname, state
ORDER BY COUNT(*) DESC;

-- ============================================================================
-- 4) Buffer cache hit ratio — should generally be > 99% for OLTP workloads;
--    a low ratio means shared_buffers may be undersized for the working set
-- ============================================================================
SELECT
    ROUND(SUM(heap_blks_hit)::numeric / NULLIF(SUM(heap_blks_hit) + SUM(heap_blks_read), 0) * 100, 2) AS cache_hit_ratio
FROM pg_statio_user_tables;

-- ============================================================================
-- 5) Top queries by total execution time (requires pg_stat_statements
--    extension: CREATE EXTENSION pg_stat_statements;)
-- ============================================================================
SELECT
    query,
    calls,
    total_exec_time,
    total_exec_time / calls AS avg_exec_time_ms,
    rows
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

-- ============================================================================
-- 6) Table and index sizes — identify what's consuming disk
-- ============================================================================
SELECT
    relname AS table_name,
    pg_size_pretty(pg_total_relation_size(relid)) AS total_size,
    pg_size_pretty(pg_relation_size(relid))        AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC
LIMIT 20;

-- ============================================================================
-- 7) Replication lag (run on the primary, requires connected replicas)
-- ============================================================================
SELECT
    client_addr, state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS replication_lag_bytes
FROM pg_stat_replication;

-- ============================================================================
-- 8) Unused indexes — write overhead with no read benefit
-- ============================================================================
SELECT
    schemaname, relname AS table_name, indexrelname AS index_name,
    idx_scan, pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;
