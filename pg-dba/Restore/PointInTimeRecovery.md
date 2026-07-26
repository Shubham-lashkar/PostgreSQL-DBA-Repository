# Point-In-Time Recovery (PITR)

Physical backups (`pg_basebackup`) combined with continuous WAL archiving let you restore a database to **any specific moment** — not just the moment a backup was taken. Essential for recovering from accidental `DELETE`/`DROP` statements or corruption.

## Prerequisites

`postgresql.conf`:
```conf
wal_level = replica
archive_mode = on
archive_command = 'cp %p /archive/wal/%f'
```

## Recovery steps

1. **Stop PostgreSQL** on the target server
2. **Restore the base backup** into the data directory:
   ```bash
   rm -rf /var/lib/postgresql/16/main/*
   tar -xzf /backups/postgresql/basebackup_TIMESTAMP.tar.gz -C /var/lib/postgresql/16/main/
   ```
3. **Create `recovery.signal`** (PostgreSQL 12+) in the data directory to trigger recovery mode
4. **Configure recovery target** in `postgresql.conf`:
   ```conf
   restore_command = 'cp /archive/wal/%f %p'
   recovery_target_time = '2026-07-25 14:30:00'
   ```
5. **Start PostgreSQL** — it replays WAL from the base backup up to the target time, then stops in a consistent state
6. **Verify data**, then promote if this is meant to become the new primary:
   ```bash
   psql -c "SELECT pg_promote();"
   ```

## Recovery target options
- `recovery_target_time` — restore to a specific timestamp
- `recovery_target_xid` — restore to just before/after a specific transaction ID
- `recovery_target_lsn` — restore to a specific WAL LSN
- `recovery_target_name` — restore to a named restore point (`pg_create_restore_point()`)

## Testing PITR
Always test recovery on a non-production server periodically — an untested backup strategy is not a real backup strategy. Verify both the base backup restore and WAL replay work end-to-end.

## Related files
- `Backup/pg_dump_backup.sh` (step 6 — base backup creation)
- `Replication/` — WAL archiving is also the foundation of streaming replication
