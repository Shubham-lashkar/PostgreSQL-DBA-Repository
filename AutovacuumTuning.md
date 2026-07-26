# Autovacuum Tuning

## What autovacuum does
A background process that automatically runs `VACUUM` and `ANALYZE` when a table's dead-tuple count crosses a threshold, so DBAs don't have to manually schedule vacuuming for every table.

## Default thresholds (instance-wide, `postgresql.conf`)
```conf
autovacuum_vacuum_scale_factor = 0.2    # vacuum when dead tuples > 20% of table + threshold
autovacuum_vacuum_threshold = 50
autovacuum_analyze_scale_factor = 0.1
autovacuum_analyze_threshold = 50
```

## Why defaults are wrong for large, high-churn tables
20% of a 10-row table is 2 rows — fine. 20% of a 50-million-row table is 10 million dead rows before autovacuum even triggers — by then the table is badly bloated and the vacuum itself takes a long time and competes with production I/O.

## Fix: per-table overrides (see `Vacuum/vacuum_maintenance.sql`)
```sql
ALTER TABLE orders SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_vacuum_threshold = 1000
);
```
Lower scale factor + a fixed threshold means large, hot tables get vacuumed proportionally more often, before bloat accumulates significantly.

## Symptoms of insufficient autovacuum tuning
- Growing gap between `n_live_tup` and actual row count expected
- Query plans degrading over time on tables that haven't changed structurally
- `last_autovacuum` timestamps far in the past on high-write tables
- Index bloat (indexes reference dead tuples too — `REINDEX` may be needed alongside vacuum)

## Key instance-wide settings worth reviewing
| Setting | Purpose |
|---|---|
| `autovacuum_max_workers` | How many tables can be vacuumed concurrently (default 3 — often too low for many large tables) |
| `autovacuum_vacuum_cost_limit` | Throttles autovacuum I/O impact on production; raising it lets vacuum run faster at the cost of more I/O contention |
| `maintenance_work_mem` | Memory available for vacuum — higher speeds up large table vacuums |

## Related scripts
- `Vacuum/vacuum_maintenance.sql`
