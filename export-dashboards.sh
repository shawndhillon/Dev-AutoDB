#!/bin/bash
set -e

GRAFANA_URL="http://localhost:3000"
OUTPUT_DIR="k8s/dashboards"

mkdir -p "$OUTPUT_DIR"

echo "Exporting dashboards from Grafana..."

# Get all dashboard UIDs
UIDS=$(curl -s "$GRAFANA_URL/api/search?type=dash-db" | jq -r '.[].uid')

for uid in $UIDS; do
  echo "Exporting dashboard: $uid"
  curl -s "$GRAFANA_URL/api/dashboards/uid/$uid" | \
    jq '.dashboard' > "$OUTPUT_DIR/${uid}.json"
done

echo "Dashboards exported to $OUTPUT_DIR"
