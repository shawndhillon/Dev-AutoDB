#!/bin/bash
set -e

NAMESPACE="${NAMESPACE:-pg-monitor}"
TARGET="${1:-}"

if [[ -z "$TARGET" ]] || [[ ! "$TARGET" =~ ^(primary|replica)$ ]]; then
  echo "Usage: ./kill.sh [primary|replica]"
  echo ""
  echo "Examples:"
  echo "  ./kill.sh primary   # Kill PostgreSQL primary pod"
  echo "  ./kill.sh replica   # Kill PostgreSQL replica pod"
  exit 1
fi

# Determine pod label
if [[ "$TARGET" == "primary" ]]; then
  LABEL="app=postgres,role=primary"
else
  LABEL="app=postgres,role=replica"
fi

# Wait for pod to be ready
echo "Waiting for $TARGET pod to be ready..."
MAX_WAIT=60
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
  POD_NAME=$(kubectl get pods -n $NAMESPACE -l $LABEL --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

  if [[ -n "$POD_NAME" ]]; then
    echo "Found running $TARGET pod: $POD_NAME"
    break
  fi

  sleep 2
  ELAPSED=$((ELAPSED + 2))
done

if [[ -z "$POD_NAME" ]]; then
  echo "ERROR: No running $TARGET pod found in namespace $NAMESPACE after ${MAX_WAIT}s"
  echo "Tip: Run ./start.sh first and wait for pods to be ready"
  exit 1
fi

# Delete the pod
echo "Deleting $TARGET pod: $POD_NAME"
kubectl delete pod -n $NAMESPACE $POD_NAME

echo "Done. Kubernetes will recreate the pod automatically."
