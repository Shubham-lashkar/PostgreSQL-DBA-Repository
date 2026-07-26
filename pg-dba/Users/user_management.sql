/*
================================================================================
 File    : user_management.sql
 Purpose : Individual login accounts, built on top of the group roles
           defined in Roles/role_management.sql, plus password policy and
           connection security.
 Author  : Shubham Lashkar
================================================================================
*/

-- ============================================================================
-- 1) Create individual login users and assign them to a group role
--    (grants flow from the group role — no need to grant table permissions
--    to each user individually)
-- ============================================================================
CREATE ROLE shubham_dev WITH LOGIN PASSWORD 'use-a-strong-password-here' VALID UNTIL '2027-01-01';
GRANT app_readwrite TO shubham_dev;

CREATE ROLE reporting_svc WITH LOGIN PASSWORD 'use-a-strong-password-here';
GRANT app_readonly TO reporting_svc;

-- ============================================================================
-- 2) Connection limits — prevent a single account from exhausting
--    max_connections
-- ============================================================================
ALTER ROLE reporting_svc CONNECTION LIMIT 10;

-- ============================================================================
-- 3) Password expiry and rotation policy
-- ============================================================================
ALTER ROLE shubham_dev VALID UNTIL '2027-01-01';

-- Force password change tracking via a separate audit table (PostgreSQL has
-- no built-in password history/complexity enforcement — use an extension
-- like passwordcheck, or enforce policy at the application/IAM layer)

-- ============================================================================
-- 4) Disable a user account without dropping it (preserves ownership of
--    objects they created — dropping a role that owns objects fails or
--    requires reassignment first)
-- ============================================================================
ALTER ROLE shubham_dev NOLOGIN;

-- Re-enable
-- ALTER ROLE shubham_dev LOGIN;

-- ============================================================================
-- 5) Safely dropping a user — reassign owned objects first
-- ============================================================================
REASSIGN OWNED BY shubham_dev TO app_admin;
DROP OWNED BY shubham_dev;
DROP ROLE IF EXISTS shubham_dev;

-- ============================================================================
-- 6) Auditing login activity
-- ============================================================================
SELECT usename, application_name, client_addr, backend_start, state
FROM pg_stat_activity
WHERE usename IS NOT NULL
ORDER BY backend_start DESC;

-- ============================================================================
-- 7) Restricting connections by source (pg_hba.conf, not SQL — reference)
-- ============================================================================
-- host    orderdb    reporting_svc    10.0.0.0/24    scram-sha-256
-- Prefer scram-sha-256 over md5 for password authentication (stronger hashing)
