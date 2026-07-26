# 🐘 PostgreSQL DBA Repository

![PostgreSQL](https://img.shields.io/badge/PostgreSQL-4169E1?style=flat&logo=postgresql&logoColor=white)
![Bash](https://img.shields.io/badge/Bash-4EAA25?style=flat&logo=gnu-bash&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

A practical PostgreSQL DBA reference — backup/recovery, vacuum & statistics maintenance, monitoring, role-based security, replication, and performance tuning, built around real production scenarios.

## 📂 Repository Structure

| Folder | Contents |
|---|---|
| [`Backup/`](./Backup) | `pg_dump`/`pg_basebackup` strategies — logical vs physical backups |
| [`Restore/`](./Restore) | Restore procedures + Point-In-Time Recovery (PITR) |
| [`Vacuum/`](./Vacuum) | VACUUM, VACUUM FULL, autovacuum tuning, bloat detection |
| [`Analyze/`](./Analyze) | Statistics refresh, planner selectivity, `pg_stats` inspection |
| [`Monitoring/`](./Monitoring) | Active queries, blocking chains, cache hit ratio, replication lag |
| [`Roles/`](./Roles) | Group roles, grants, Row-Level Security (RLS) |
| [`Users/`](./Users) | Individual login accounts, password policy, connection limits |
| [`Replication/`](./Replication) | Streaming (physical) and logical replication setup |
| [`Performance/`](./Performance) | Index types (B-tree, GIN, BRIN), `EXPLAIN ANALYZE`, `work_mem` tuning |

## 🛠️ Tech Stack
PostgreSQL 16 · Bash · psql · `pg_stat_statements`

## 👤 Author
**Shubham Lashkar** — Senior SQL Developer | SQL Server & PostgreSQL | ETL/SSIS | AWS Databases

## 📄 License
MIT
