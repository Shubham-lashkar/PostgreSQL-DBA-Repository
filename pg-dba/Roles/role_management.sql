/*
================================================================================
 File    : role_management.sql
 Purpose : PostgreSQL role-based access control — groups, inheritance, and
           least-privilege grants. PostgreSQL has no separate "user" concept
           at the engine level; roles with LOGIN are users (see Users/ for
           the individual-account layer built on top of these roles).
 Author  : Shubham Lashkar
================================================================================
*/

-- ============================================================================
-- 1) Group roles — no LOGIN, used purely to bundle permissions
-- ============================================================================
CREATE ROLE app_readonly NOLOGIN;
CREATE ROLE app_readwrite NOLOGIN;
CREATE ROLE app_admin NOLOGIN;

-- ============================================================================
-- 2) Grant schema-level and table-level privileges to each group role
-- ============================================================================
GRANT USAGE ON SCHEMA public TO app_readonly, app_readwrite, app_admin;

GRANT SELECT ON ALL TABLES IN SCHEMA public TO app_readonly;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_readwrite;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO app_admin;

-- Ensure future tables automatically inherit these grants (without this,
-- newly created tables have no grants for these roles by default)
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO app_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_readwrite;

-- Sequence usage needed for readwrite roles to use SERIAL/IDENTITY columns
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO app_readwrite;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO app_readwrite;

-- ============================================================================
-- 3) Row-Level Security (RLS) — restrict which rows a role can see, not
--    just which tables/columns
-- ============================================================================
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY regional_orders_policy ON orders
    FOR SELECT
    TO app_readonly
    USING (shipping_city = current_setting('app.current_region', true));

-- ============================================================================
-- 4) Auditing role membership and grants
-- ============================================================================
-- Which roles exist and their attributes
SELECT rolname, rolsuper, rolcreaterole, rolcreatedb, rolcanlogin, rolconnlimit
FROM pg_roles
ORDER BY rolname;

-- Which roles a given role is a member of (inherited permissions)
SELECT r.rolname AS role, m.rolname AS member_of
FROM pg_auth_members am
JOIN pg_roles r ON r.oid = am.member
JOIN pg_roles m ON m.oid = am.roleid;

-- Table-level grants for a specific role
SELECT grantee, table_name, privilege_type
FROM information_schema.table_privileges
WHERE grantee = 'app_readwrite';

-- ============================================================================
-- 5) Revoking privileges (principle of least privilege — start restrictive,
--    grant only what's proven necessary)
-- ============================================================================
REVOKE ALL ON DATABASE orderdb FROM PUBLIC;  -- PUBLIC gets CONNECT by default; remove blanket access
GRANT CONNECT ON DATABASE orderdb TO app_readonly, app_readwrite, app_admin;
