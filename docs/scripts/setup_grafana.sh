#!/usr/bin/env bash
# Add Loki datasource + a starter SIEM dashboard to Grafana via API.
# Usage: ./setup_grafana.sh [grafana_url] [user:pass]
set -euo pipefail

GRAFANA="${1:-http://localhost:3000}"
AUTH="${2:-admin:admin}"

echo "==> Adding Loki datasource"
if curl -fsS "$GRAFANA/api/datasources/name/Loki" -u "$AUTH" >/dev/null; then
  echo "Loki datasource already exists"
else
  curl -fsS -X POST "$GRAFANA/api/datasources" \
    -u "$AUTH" -H 'Content-Type: application/json' \
    -d '{"name":"Loki","type":"loki","access":"proxy","url":"http://localhost:3100","isDefault":true,"jsonData":{"maxLines":1000}}' | jq .
fi
LOKI_UID=$(curl -fsS "$GRAFANA/api/datasources/name/Loki" -u "$AUTH" | jq -er '.uid')

echo "==> Creating starter dashboard (Suricata alerts + Zeek DNS + event rate)"
DASHBOARD_JSON=$(cat <<'EOF'
{
  "dashboard": {
    "title": "SIEM - Suricata & Zeek (Loki)",
    "tags": ["siem","loki"],
    "timezone": "browser",
    "panels": [
      {
        "id": 1, "type": "table", "title": "Suricata Alerts",
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 0},
        "targets": [{"expr": "{job=\"siem\",sensor=\"sensor-suricata\",event_type=\"evt-alert\"}", "refId": "A"}],
        "datasource": {"type": "loki", "uid": "loki"}
      },
      {
        "id": 2, "type": "table", "title": "Zeek DNS Queries",
        "gridPos": {"h": 10, "w": 24, "x": 0, "y": 10},
        "targets": [{"expr": "{job=\"siem\",sensor=\"sensor-zeek\"} | json | event_type=\"dns\"", "refId": "A"}],
        "datasource": {"type": "loki", "uid": "loki"}
      },
      {
        "id": 3, "type": "stat", "title": "Event Rate (events/min)",
        "gridPos": {"h": 4, "w": 8, "x": 0, "y": 20},
        "targets": [{"expr": "sum(rate({job=\"siem\"}[1m])) * 60", "refId": "A"}],
        "datasource": {"type": "loki", "uid": "loki"}
      }
    ],
    "schemaVersion": 39, "version": 0
  },
  "overwrite": true
}
EOF
)
DASHBOARD_JSON=$(jq --arg uid "$LOKI_UID" '.dashboard.panels[].datasource.uid = $uid' <<< "$DASHBOARD_JSON")
curl -fsS -X POST "$GRAFANA/api/dashboards/db" \
  -u "$AUTH" -H 'Content-Type: application/json' \
  -d "$DASHBOARD_JSON" | jq .

echo "==> Done. Open $GRAFANA and look for 'SIEM - Suricata & Zeek (Loki)'"
