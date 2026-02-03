#!/bin/bash
set -e

echo "=== Starting ==="

# Configuration
CLUSTER_NAME="${CLUSTER_NAME:-pg-monitor-dev}"
NAMESPACE="${NAMESPACE:-pg-monitor}"

# Trap handler for cleanup on Ctrl+C
cleanup() {
  echo ""
  echo "Stopping skaffold..."
  if [[ -n "$SKAFFOLD_PID" ]]; then
    kill "$SKAFFOLD_PID" 2>/dev/null || true
    wait "$SKAFFOLD_PID" 2>/dev/null || true
  fi
  echo "Stopped."
  exit 0
}

trap cleanup INT TERM

# Check if k3d cluster exists, create if needed
if ! k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "Creating k3d cluster: $CLUSTER_NAME"
  k3d cluster create $CLUSTER_NAME
else
  echo "Cluster $CLUSTER_NAME already exists"
fi

# Set kubectl context
kubectl config use-context k3d-$CLUSTER_NAME

# Ensure namespace exists before skaffold runs
echo "Ensuring namespace $NAMESPACE exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Start skaffold dev in background
echo "Starting skaffold dev..."
skaffold dev &
SKAFFOLD_PID=$!

# Wait for services to be ready
echo "Waiting for services to be ready..."
MAX_WAIT=120
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  READY_COUNT=$(kubectl get pods -n $NAMESPACE --no-headers 2>/dev/null | grep -c "Running" || true)
  READY_COUNT=${READY_COUNT:-0}

  if [ "$READY_COUNT" -ge 3 ]; then
    echo "Services are ready!"
    break
  fi

  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
  echo "Warning: Services did not become ready within $MAX_WAIT seconds"
else
  echo ""
  echo "=== Services ==="
  echo ""
  echo "  Grafana:    http://localhost:3000"
  echo "  Prometheus: http://localhost:9090"
  echo "  PostgreSQL: localhost:5432"
  echo ""
  echo "Press Ctrl+C to stop."
fi

# Wait for skaffold to finish
wait $SKAFFOLD_PID
