# Replication Setup

## Streaming Replication (physical, async by default)

### On the primary
`postgresql.conf`:
```conf
wal_level = replica
max_wal_senders = 10
wal_keep_size = 1GB
```

`pg_hba.conf`:
```conf
host    replication    replicator    10.0.1.0/24    scram-sha-256
```

Create a dedicated replication role:
```sql
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'use-a-strong-password-here';
```

### On the replica
```bash
pg_basebackup -h primary_host -U replicator -D /var/lib/postgresql/16/main -F p -X stream -P -R
```
The `-R` flag automatically writes `standby.signal` and the connection info needed for the replica to start streaming from the primary.

Start PostgreSQL on the replica — it connects to the primary and begins streaming WAL.

## Synchronous vs Asynchronous replication

| | Async (default) | Sync |
|---|---|---|
| Primary commit waits for replica ack? | No | Yes |
| Data loss risk on primary failure | Small window possible | None (for synced transactions) |
| Write latency impact | None | Adds replica round-trip time |

Enable synchronous replication:
```conf
# postgresql.conf on primary
synchronous_standby_names = 'replica1'
```

## Logical Replication (row-level, cross-version capable)

Used for selective table replication, zero-downtime major version upgrades, or feeding a reporting/ETL pipeline without replicating the entire cluster.

### On the publisher (source)
```sql
CREATE PUBLICATION orders_pub FOR TABLE orders, order_details;
```

### On the subscriber (target)
```sql
CREATE SUBSCRIPTION orders_sub
CONNECTION 'host=primary_host dbname=orderdb user=replicator password=...'
PUBLICATION orders_pub;
```

Unlike streaming replication, logical replication:
- Replicates specific tables, not the whole cluster
- Works across different PostgreSQL major versions
- Allows the subscriber to have additional local tables/indexes not on the publisher
- Does **not** replicate DDL automatically — schema changes must be applied on both sides

## Monitoring replication
See `Monitoring/monitoring_queries.sql` (query #7) for `pg_stat_replication` and lag calculation.

## Failover considerations
Streaming replication alone is not automatic failover — pairing with a tool like **Patroni**, **repmgr**, or a cloud-managed service (e.g. AWS RDS Multi-AZ) is standard practice for production HA rather than manual promotion.
