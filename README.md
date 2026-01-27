## Docker Path

### Prereqs
- [Docker Desktop](https://www.docker.com/products/docker-desktop) — start it before running commands
- [lazydocker](https://github.com/jesseduffield/lazydocker) (optional) — terminal UI for Docker
- [pgAdmin Desktop](https://www.pgadmin.org/download/) (optional) — GUI for database management

## Kubernetes Path

### Prerequisites
- [Docker Desktop](https://www.docker.com/products/docker-desktop) — needed to build images
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [minikube](https://minikube.sigs.k8s.io/docs/start/) or [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) — start one before running commands
- [k9s](https://k9scli.io/topics/install/) (optional) — terminal UI for Kubernetes

---

## pgAdmin Desktop Setup

Download pgAdmin Desktop from [pgadmin.org/download](https://www.pgadmin.org/download/)

Add each server (right-click Servers > Register > Server):

**Primary**
```
General: Name = Primary
Connection: Host=localhost, Port=5432, Username=postgres, Password=postgres, Database=testdb
```

**Replica1**
```
General: Name = Replica1
Connection: Host=localhost, Port=5433, Username=postgres, Password=postgres, Database=testdb
```

**Replica2**
```
General: Name = Replica2
Connection: Host=localhost, Port=5434, Username=postgres, Password=postgres, Database=testdb
```

For Kubernetes: `kubectl port-forward svc/postgres-primary 5432:5432`

---

## SQL Reference

```sql
-- Am I primary or replica?
SELECT pg_is_in_recovery();  -- f=primary, t=replica

-- Replication status (run on primary)
SELECT client_addr, state FROM pg_stat_replication;

-- Replication lag
SELECT client_addr, pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes FROM pg_stat_replication;

-- Promote replica to primary
SELECT pg_promote();
```

---

## Resources

- [PostgreSQL Streaming Replication](https://www.postgresql.org/docs/16/warm-standby.html#STREAMING-REPLICATION)
- [pg_stat_replication](https://www.postgresql.org/docs/16/monitoring-stats.html#MONITORING-PG-STAT-REPLICATION-VIEW)
- [Docker Hub: postgres](https://hub.docker.com/_/postgres)
