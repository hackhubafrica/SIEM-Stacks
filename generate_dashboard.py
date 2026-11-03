#!/usr/bin/env python3
import json

ES_UID = "dg25outs9pxq8a"

def es_panel(panel_id, title, query, aggs, grid_y, grid_h=8, grid_w=12, grid_x=0, panel_type="bargauge", metric_type="count", metric_field="*"):
    target = {
        "refId": "A",
        "datasource": {"type": "elasticsearch", "uid": ES_UID},
        "query": query,
        "timeField": "@timestamp",
        "metrics": [{"id": "1", "type": metric_type, "field": metric_field}],
        "bucketAggs": aggs
    }
    panel = {
        "id": panel_id,
        "type": panel_type,
        "title": title,
        "gridPos": {"h": grid_h, "w": grid_w, "x": grid_x, "y": grid_y},
        "datasource": {"type": "elasticsearch", "uid": ES_UID},
        "targets": [target],
        "options": {}
    }
    if panel_type == "bargauge":
        panel["options"] = {"orientation": "horizontal", "showValue": True,
            "valueOptions": {"textMode": "value", "colorMode": "value", "text": {}}}
    elif panel_type == "timeseries":
        panel["options"] = {"tooltip": {"mode": "single"}, "legend": {"show": True}}
    elif panel_type == "table":
        panel["options"] = {"showHeader": True}
    elif panel_type == "stat":
        panel["options"] = {
            "reduceOptions": {"values": False, "calcs": ["count"], "fields": ""},
            "orientation": "auto", "textMode": "value_and_name",
            "colorMode": "value", "graphMode": "none", "justifyMode": "center"
        }
    return panel

panels = []

# Row 1: Wazuh Alerts Over Time (full width)
panels.append(es_panel(1, "Wazuh Alerts Over Time", "wazuh-alerts-*", [
    {"id": "2", "type": "date_histogram", "field": "@timestamp",
     "settings": {"interval": "auto", "min_doc_count": 0, "extended_bounds": {}}}
], 0, 8, 24, 0, "timeseries"))

# Row 2: Alerts by Severity + Top Source IPs
panels.append(es_panel(2, "Alerts by Severity", "wazuh-alerts-*", [
    {"id": "2", "type": "terms", "field": "rule.level", "size": 10, "order": "desc", "orderBy": "1"}
], 8, 8, 12, 0))
panels.append(es_panel(3, "Top Source IPs", "wazuh-alerts-*", [
    {"id": "2", "type": "terms", "field": "srcip", "size": 10, "order": "desc", "orderBy": "1"}
], 8, 8, 12, 12))

# Row 3: Recent Alerts Table + Total Alerts + High Severity + Rules Loaded + Pipeline Status
panels.append(es_panel(4, "Recent Wazuh Alerts", "wazuh-alerts-*", [
    {"id": "2", "type": "terms", "field": "rule.description", "size": 50, "order": "desc", "orderBy": "1"}
], 16, 10, 24, 0, "table"))

panels.append(es_panel(5, "Total Alerts (1h)", "wazuh-alerts-*", [], 26, 4, 6, 0, "stat"))
panels.append(es_panel(6, "High Severity (level >= 12)", "wazuh-alerts-* AND rule.level:[12 TO *]", [], 26, 4, 6, 6, "stat"))
panels.append(es_panel(7, "Suricata Rules Loaded", "suricata-* AND event_type:stats", [
    {"id": "2", "type": "avg", "field": "stats.detect.engines.rules_loaded"}
], 26, 4, 6, 12, "stat"))
panels.append(es_panel(8, "Pipeline Status", "*", [], 26, 4, 6, 18, "stat"))

# Row 4: Protocol Distribution + Detect Engines
panels.append(es_panel(9, "Suricata Protocol Distribution", "suricata-* AND event_type:stats", [
    {"id": "2", "type": "date_histogram", "field": "@timestamp",
     "settings": {"interval": "auto", "min_doc_count": 0, "extended_bounds": {}}}
], 30, 10, 12, 0, "timeseries"))
panels.append(es_panel(10, "Suricata Detect Engines", "suricata-* AND event_type:stats", [
    {"id": "2", "type": "terms", "field": "stats.detect.engines.id", "size": 10, "order": "asc", "orderBy": "_key"}
], 40, 8, 24, 0, "bargauge"))

# Row 5: Event Rate
panels.append(es_panel(11, "Event Rate (all indices)", "*", [
    {"id": "2", "type": "date_histogram", "field": "@timestamp",
     "settings": {"interval": "auto", "min_doc_count": 0, "extended_bounds": {}}}
], 48, 8, 24, 0, "timeseries"))

dashboard = {
    "dashboard": {
        "title": "SIEM - Wazuh + Suricata + Zeek (Elasticsearch)",
        "tags": ["siem", "elasticsearch", "wazuh", "suricata", "zeek"],
        "timezone": "browser",
        "time": {"from": "now-1h", "to": "now"},
        "refresh": "30s",
        "panels": panels
    },
    "overwrite": True
}

with open("/home/th3blaacksh33p/Documents/SIEM/docs/configs/grafana-dashboard-es.json", "w") as f:
    json.dump(dashboard, f, indent=2)

print("Dashboard written with", len(panels), "panels")
print("Valid JSON check:", end=" ")
with open("/home/th3blaacksh33p/Documents/SIEM/docs/configs/grafana-dashboard-es.json") as f:
    json.load(f)
print("OK")