#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-pg-monitor}"
DURATION="${DURATION:-10}"

echo "=== Simulating Replication Lag ==="

# Wait for primary pod to be ready
echo "Waiting for primary pod to be ready..."
MAX_WAIT=60
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  PRIMARY_POD=$(kubectl get pods -n $NAMESPACE -l app=postgres,role=primary --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$PRIMARY_POD" ]]; then
    echo "Found running primary pod: $PRIMARY_POD"
    break
  fi

  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

if [[ -z "$PRIMARY_POD" ]]; then
  echo "ERROR: No running primary pod found in namespace $NAMESPACE after ${MAX_WAIT}s"
  echo "Tip: Run ./start.sh first and wait for pods to be ready"
  exit 1
fi

# Create load on primary to generate lag
echo "Creating load on primary for $DURATION seconds..."
kubectl exec -n $NAMESPACE $PRIMARY_POD -- bash -c "
  psql -U postgres -d testdb -c 'CREATE TABLE IF NOT EXISTS lag_test (id SERIAL PRIMARY KEY, data TEXT, created_at TIMESTAMP DEFAULT NOW());' > /dev/null 2>&1 || true
  for i in {1..$DURATION}; do
    psql -U postgres -d testdb -c \"INSERT INTO lag_test (data) SELECT md5(random()::text) FROM generate_series(1, 1000);\" > /dev/null 2>&1
    sleep 1
  done
" &

LOAD_PID=$!

# Wait for load to finish
echo "Generating load..."
wait $LOAD_PID 2>/dev/null || true

# Show current lag
echo ""
echo "=== Current Replication Lag ==="
kubectl exec -n $NAMESPACE $PRIMARY_POD -- psql -U postgres -d testdb -c "
SELECT
  application_name,
  state,
  sync_state,
  pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
  pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_size
FROM pg_stat_replication;
" 2>/dev/null || echo "No replication connections found"
