#!/bin/bash
################################################################################
# File    : pg_restore.sh
# Purpose : Restore procedures for each backup format produced by
#           Backup/pg_dump_backup.sh
# Author  : Shubham Lashkar
################################################################################

DB_NAME="orderdb_restored"
DB_USER="postgres"

# ==============================================================================
# 1) Restore from custom-format dump — create target DB first, then restore
#    in parallel across 4 workers
# ==============================================================================
createdb -U "$DB_USER" "$DB_NAME"
pg_restore -U "$DB_USER" -d "$DB_NAME" -j 4 --verbose /backups/postgresql/orderdb_custom_TIMESTAMP.dump

# ==============================================================================
# 2) Restore from plain SQL dump — via psql, not pg_restore
# ==============================================================================
# createdb -U "$DB_USER" "$DB_NAME"
# psql -U "$DB_USER" -d "$DB_NAME" -f /backups/postgresql/orderdb_plain_TIMESTAMP.sql

# ==============================================================================
# 3) Restore from directory format
# ==============================================================================
# createdb -U "$DB_USER" "$DB_NAME"
# pg_restore -U "$DB_USER" -d "$DB_NAME" -j 4 /backups/postgresql/orderdb_dir_TIMESTAMP

# ==============================================================================
# 4) Selective restore — only specific tables from a custom-format dump
#    (only possible with custom/directory formats, not plain SQL)
# ==============================================================================
# pg_restore -U "$DB_USER" -d "$DB_NAME" -t orders -t order_details \
#   /backups/postgresql/orderdb_custom_TIMESTAMP.dump

# ==============================================================================
# 5) Restore full cluster (roles + all databases) from pg_dumpall output
# ==============================================================================
# psql -U "$DB_USER" -f /backups/postgresql/cluster_full_TIMESTAMP.sql postgres

# ==============================================================================
# 6) List contents of a custom-format dump without restoring
#    (useful to verify what a backup actually contains before restoring)
# ==============================================================================
# pg_restore --list /backups/postgresql/orderdb_custom_TIMESTAMP.dump

echo "Restore completed into database: $DB_NAME"
