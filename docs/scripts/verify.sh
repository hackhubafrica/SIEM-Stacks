#!/usr/bin/env bash
set -u
echo "== Loki ready =="
curl -s -m 3 http://localhost:3100/ready && echo
echo "== Grafana health =="
curl -s -m 3 -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/health
echo "== Services =="
for s in loki grafana suricata vector; do printf "%-10s " "$s"; systemctl is-active "$s"; done
echo "== Loki labels =="
curl -s -m 3 'http://localhost:3100/loki/api/v1/label/sensor/values' | jq -r '.data[]' 2>/dev/null
echo "== Zeek status =="
sudo zeekctl status 2>/dev/null | head -5
echo "== Suricata last eve line =="
sudo tail -n 1 /var/log/suricata/eve.json 2>/dev/null | jq -c '{ts,event_type}' 2>/dev/null
echo "== Vector validation =="
vector validate /etc/vector/vector.toml 2>&1 | tail -3
