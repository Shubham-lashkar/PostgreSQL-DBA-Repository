# Backup Strategies

## Logical vs Physical backups

| | Logical (`pg_dump`) | Physical (`pg_basebackup`) |
|---|---|---|
| What it captures | SQL statements to recreate objects/data | Raw data files (byte-for-byte) |
| Restore target | Same or different PostgreSQL version | Same major version, same architecture |
| Selective restore | Yes — specific tables/schemas | No — all-or-nothing |
| Speed on large DBs | Slower (logical rebuild) | Faster (file copy) |
| Point-in-time recovery | No | Yes, with WAL archiving |
| Typical use | Migrations, single-DB backup, version upgrades | Full-instance DR, replication base |

## Format comparison (`pg_dump -F`)

- **`p` (plain)** — SQL text, editable, restore via `psql`. No compression, no parallel restore.
- **`c` (custom)** — compressed, supports `pg_restore --jobs N` for parallel restore, supports selective restore of specific tables via `-t`. **Recommended default.**
- **`d` (directory)** — one file per table, supports parallel **dump** (`-j`) in addition to parallel restore. Best for very large databases.
- **`t` (tar)** — similar to directory but as a single tar file; less flexible than `d`.

## Backup schedule used in `pg_dump_backup.sh`
- Daily: custom-format `pg_dump` of the application database
- Weekly: full `pg_dumpall` for cluster-wide role/database recreation
- Continuous: WAL archiving for PITR (see `Restore/PointInTimeRecovery.md`)
- Retention: 14 days for logical dumps, adjust based on RPO/RTO requirements and storage cost

## What backups alone don't cover
- Role/permission definitions are **not** included in a per-database `pg_dump` — use `pg_dumpall --globals-only` or a full `pg_dumpall` for those
- Extensions must be present on the restore target before data referencing them restores correctly
