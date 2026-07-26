#!/bin/bash
################################################################################
# File    : pg_dump_backup.sh
# Purpose : Backup strategies for PostgreSQL — logical (pg_dump) and physical
#           (pg_basebackup), covering the trade-offs of each format.
# Author  : Shubham Lashkar
################################################################################

DB_NAME="orderdb"
DB_USER="postgres"
BACKUP_DIR="/backups/postgresql"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# ==============================================================================
# 1) Plain SQL dump — human-readable, restorable with psql, best for small DBs
#    or when you need to inspect/edit the dump before restoring
# ==============================================================================
pg_dump -U "$DB_USER" -d "$DB_NAME" -F p -f "$BACKUP_DIR/${DB_NAME}_plain_${TIMESTAMP}.sql"

# ==============================================================================
# 2) Custom format — compressed, supports selective restore (specific tables/
#    schemas) and parallel restore. This is the recommended default for
#    production logical backups.
# ==============================================================================
pg_dump -U "$DB_USER" -d "$DB_NAME" -F c -Z 9 -f "$BACKUP_DIR/${DB_NAME}_custom_${TIMESTAMP}.dump"

# ==============================================================================
# 3) Directory format with parallel dump — fastest logical backup for large
#    databases; each table dumped by a separate worker process
# ==============================================================================
pg_dump -U "$DB_USER" -d "$DB_NAME" -F d -j 4 -f "$BACKUP_DIR/${DB_NAME}_dir_${TIMESTAMP}"

# ==============================================================================
# 4) Schema-only backup — useful for versioning DDL separately from data
# ==============================================================================
pg_dump -U "$DB_USER" -d "$DB_NAME" --schema-only -f "$BACKUP_DIR/${DB_NAME}_schema_${TIMESTAMP}.sql"

# ==============================================================================
# 5) Full cluster backup (all databases + roles) — for disaster recovery of
#    the entire instance, not just one database
# ==============================================================================
pg_dumpall -U "$DB_USER" -f "$BACKUP_DIR/cluster_full_${TIMESTAMP}.sql"

# ==============================================================================
# 6) Physical base backup — for point-in-time recovery (PITR) and replication
#    setup. Requires WAL archiving to be configured (see Replication/).
# ==============================================================================
pg_basebackup -U "$DB_USER" -D "$BACKUP_DIR/basebackup_${TIMESTAMP}" -F tar -z -P -X stream

# ==============================================================================
# Retention: delete logical dumps older than 14 days
# ==============================================================================
find "$BACKUP_DIR" -name "*.dump" -mtime +14 -delete
find "$BACKUP_DIR" -name "*.sql" -mtime +14 -delete

echo "Backup completed: $TIMESTAMP"
