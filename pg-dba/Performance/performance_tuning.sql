/*
================================================================================
 File    : performance_tuning.sql
 Purpose : Query and index optimization patterns specific to PostgreSQL's
           planner and storage engine.
 Author  : Shubham Lashkar
================================================================================
*/

-- ============================================================================
-- 1) EXPLAIN ANALYZE — always use BUFFERS to see actual I/O, not just timing
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT o.order_id, c.first_name, SUM(od.quantity * od.unit_price) AS line_total
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
JOIN order_details od ON od.order_id = o.order_id
WHERE o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY o.order_id, c.first_name;

-- ============================================================================
-- 2) B-tree index for equality/range lookups (the default and most common)
-- ============================================================================
CREATE INDEX idx_orders_customer_id ON orders (customer_id);

-- ============================================================================
-- 3) Partial index — narrower and faster than a full index for a
--    consistently-filtered subset
-- ============================================================================
CREATE INDEX idx_orders_pending ON orders (order_date)
WHERE order_status = 'Pending';

-- ============================================================================
-- 4) Covering index using INCLUDE — avoids a heap fetch for included columns
--    (PostgreSQL's equivalent of a SQL Server covering index)
-- ============================================================================
CREATE INDEX idx_orders_customer_covering ON orders (customer_id, order_date DESC)
INCLUDE (order_status, total_amount);

-- ============================================================================
-- 5) GIN index — for full-text search or JSONB containment queries, where a
--    B-tree can't help
-- ============================================================================
CREATE INDEX idx_products_search ON products USING GIN (to_tsvector('english', product_name));
-- Query: SELECT * FROM products WHERE to_tsvector('english', product_name) @@ to_tsquery('laptop');

CREATE INDEX idx_orders_metadata ON orders USING GIN (metadata jsonb_path_ops);
-- Query: SELECT * FROM orders WHERE metadata @> '{"priority": "high"}';

-- ============================================================================
-- 6) BRIN index — much smaller than B-tree, effective on very large tables
--    where the indexed column correlates strongly with physical row order
--    (e.g. an append-only orders table ordered by insertion/order_date)
-- ============================================================================
CREATE INDEX idx_orders_date_brin ON orders USING BRIN (order_date);

-- ============================================================================
-- 7) CTE materialization behavior (PostgreSQL 12+): CTEs are inlined by
--    default unless marked MATERIALIZED — know which one you're getting
-- ============================================================================
-- Inlined (optimizer can push predicates into the CTE) — usually preferred
WITH recent_orders AS (
    SELECT * FROM orders WHERE order_date >= CURRENT_DATE - 7
)
SELECT * FROM recent_orders WHERE customer_id = 4521;

-- Forced materialization (evaluated once, result cached) — use when the CTE
-- is referenced multiple times and recomputation would be expensive
WITH recent_orders AS MATERIALIZED (
    SELECT * FROM orders WHERE order_date >= CURRENT_DATE - 7
)
SELECT * FROM recent_orders;

-- ============================================================================
-- 8) Connection pooling matters more in PostgreSQL than most engines — each
--    connection is a full OS process. Use PgBouncer/PgPool in front of the
--    database rather than relying on the application to manage many raw
--    connections; verify current usage first:
-- ============================================================================
SELECT COUNT(*), state FROM pg_stat_activity GROUP BY state;
SHOW max_connections;

-- ============================================================================
-- 9) work_mem tuning — too low forces sort/hash operations to spill to disk;
--    too high (multiplied across concurrent connections) risks OOM
-- ============================================================================
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, SUM(total_amount)
FROM orders
GROUP BY customer_id
ORDER BY SUM(total_amount) DESC;
-- Look for "Sort Method: external merge  Disk:" in the plan output —
-- indicates work_mem was too small and the sort spilled to disk
