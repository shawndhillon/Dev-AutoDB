# Dev-AutoDB

## Prereqs

Install via Homebrew or google:

```bash
brew install k3d kubectl skaffold jq
```

Docker Desktop must be running.

## Quick Start

```bash
./start.sh
```

This creates a k3d cluster, deploys PostgreSQL primary+replica, and starts monitoring. Press Ctrl+C to stop.

## Chaos Testing

Simulate database failures:

```bash
# Kill the primary PostgreSQL pod
./kill.sh

# Introduce replication lag
./lag.sh
```

Watch Grafana to observe impact and recovery.

## What's Running

- **Grafana**: http://localhost:3000 (anonymous access, no login)
- **Prometheus**: http://localhost:9090 (metrics collection)
- **PostgreSQL**: localhost:5432 (user: postgres, password: postgres, db: testdb)

Connect via psql:
```bash
psql postgresql://postgres:postgres@localhost:5432/testdb
```

Check replication status:
```sql
SELECT * FROM pg_stat_replication;
```

## Architecture

- **k3d**: local Kubernetes cluster
- **PostgreSQL 16**: Streaming replication (1 primary, 1 replica)
- **postgres_exporter**: Metrics collection from PostgreSQL
- **Prometheus**: Metrics storage and alerting
- **Grafana**: Dashboards and visualization
- **Skaffold**: Automated deployment and port forwarding

## Export Dashboards

After making changes in Grafana:

```bash
./export-dashboards.sh
```

Dashboards are saved to `k8s/dashboards/*.json`

## Cleanup

```bash
k3d cluster delete pg-monitor-dev
```
