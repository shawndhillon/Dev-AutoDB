Pick one: [Docker](#docker) or [Kubernetes](#kubernetes)

---

# Docker

Make sure Docker Desktop is running.

## 1. Start

```bash
docker-compose up -d
# starts primary + 2 replicas
```

## 2. Verify

```bash
docker ps
# 3 containers: pg-primary, pg-replica1, pg-replica2

docker-compose logs primary | tail -5
# "database system is ready to accept connections"
```

## 3. Check Replication

```bash
docker exec pg-primary psql -U postgres -c "SELECT client_addr, state FROM pg_stat_replication;"
# 2 rows, state=streaming
```

## 4. Test Replication

```bash
# Write to primary
docker exec pg-primary psql -U postgres -d testdb -c "CREATE TABLE test (id serial, data text);"
docker exec pg-primary psql -U postgres -d testdb -c "INSERT INTO test (data) VALUES ('hello');"

# Read from replica — same data
docker exec pg-replica1 psql -U postgres -d testdb -c "SELECT * FROM test;"
```

## 5. Kill Replica

```bash
docker stop pg-replica1

docker exec pg-primary psql -U postgres -c "SELECT client_addr FROM pg_stat_replication;"
# 1 row now

docker start pg-replica1
# reconnects and catches up
```

## 6. Kill Primary

```bash
docker stop pg-primary

# Replicas still serve reads
docker exec pg-replica1 psql -U postgres -d testdb -c "SELECT * FROM test;"

# Writes fail
docker exec pg-replica1 psql -U postgres -d testdb -c "INSERT INTO test (data) VALUES ('x');"
# ERROR: cannot execute INSERT in a read-only transaction

docker start pg-primary
# replication resumes
```

## 7. Promote Replica

```bash
docker exec pg-replica1 psql -U postgres -c "SELECT pg_promote();"
# t

docker exec pg-replica1 psql -U postgres -c "SELECT pg_is_in_recovery();"
# f (now primary)

# Can write to it now
docker exec pg-replica1 psql -U postgres -d testdb -c "INSERT INTO test (data) VALUES ('promoted');"
```

## 8. Load Test

```bash
docker exec pg-primary pgbench -U postgres -i -s 10 testdb
docker exec pg-primary pgbench -U postgres -c 4 -T 30 testdb

# Watch lag during load
docker exec pg-primary psql -U postgres -c "SELECT client_addr, pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes FROM pg_stat_replication;"
```

## 9. Load Testing with pgAdmin Desktop

Open pgAdmin Desktop (see README.md for server connection setup).

**Insert data on Primary:**

```sql
-- Query Tool > Primary > testdb
CREATE TABLE IF NOT EXISTS load_test (
    id serial PRIMARY KEY,
    data text,
    created_at timestamp DEFAULT now()
);

-- Insert 1000 rows
INSERT INTO load_test (data)
SELECT 'data-' || generate_series(1, 1000);
```

**Verify replication on Replicas:**

```sql
-- Query Tool > Replica1 > testdb (or Replica2)
SELECT COUNT(*) FROM load_test;
-- 1000 rows

SELECT * FROM load_test ORDER BY id DESC LIMIT 5;
-- see latest inserts
```

**Check replication lag (on Primary):**

```sql
-- Query Tool > Primary > postgres
SELECT
    client_addr,
    state,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
-- lag_bytes should be 0 or very small
```

**Stress test (larger batch):**

```sql
-- Query Tool > Primary > testdb
INSERT INTO load_test (data)
SELECT 'batch-' || generate_series(1, 100000);

-- Immediately check lag on Primary
SELECT client_addr, pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
-- lag_bytes may briefly spike, then drop to 0
```

**Verify on Replicas:**

```sql
-- Query Tool > Replica1 > testdb
SELECT COUNT(*) FROM load_test;
-- 101000 rows (1000 + 100000)
```

## 10. Stop

```bash
docker-compose down -v
# -v removes volumes
```

---

# Kubernetes

Make sure minikube or kind is running.

```bash
minikube start
# or: kind create cluster
```

## 1. Start

```bash
kubectl apply -f manifests/
# creates primary + replica
```

## 2. Verify

```bash
kubectl get pods -l app=postgres
# 2 pods: postgres-primary-xxx, postgres-replica-xxx

kubectl logs deployment/postgres-primary --tail=5
# "database system is ready to accept connections"
```

## 3. Check Replication

```bash
kubectl exec deployment/postgres-primary -- psql -U postgres -c "SELECT client_addr, state FROM pg_stat_replication;"
# 1 row, state=streaming
```

## 4. Test Replication

```bash
# Write to primary
kubectl exec deployment/postgres-primary -- psql -U postgres -d testdb -c "CREATE TABLE test (id serial, data text);"
kubectl exec deployment/postgres-primary -- psql -U postgres -d testdb -c "INSERT INTO test (data) VALUES ('hello');"

# Read from replica — same data
kubectl exec deployment/postgres-replica -- psql -U postgres -d testdb -c "SELECT * FROM test;"
```

## 5. Kill Replica

```bash
kubectl delete pod -l role=replica

kubectl exec deployment/postgres-primary -- psql -U postgres -c "SELECT client_addr FROM pg_stat_replication;"
# 0 rows briefly

kubectl get pods -l role=replica -w
# watch it restart and reconnect
```

## 6. Kill Primary

```bash
kubectl delete pod -l role=primary

# Replica still serves reads
kubectl exec deployment/postgres-replica -- psql -U postgres -d testdb -c "SELECT * FROM test;"

# Writes fail
kubectl exec deployment/postgres-replica -- psql -U postgres -d testdb -c "INSERT INTO test (data) VALUES ('x');"
# ERROR: cannot execute INSERT in a read-only transaction

kubectl get pods -l role=primary -w
# watch it restart
```

## 7. Promote Replica

```bash
kubectl exec deployment/postgres-replica -- psql -U postgres -c "SELECT pg_promote();"
# t

kubectl exec deployment/postgres-replica -- psql -U postgres -c "SELECT pg_is_in_recovery();"
# f (now primary)
```

## 8. Load Test

```bash
kubectl exec deployment/postgres-primary -- pgbench -U postgres -i -s 10 testdb
kubectl exec deployment/postgres-primary -- pgbench -U postgres -c 4 -T 30 testdb
```

## 9. Stop

```bash
kubectl delete -f manifests/
kubectl delete pvc -l app=postgres
```
