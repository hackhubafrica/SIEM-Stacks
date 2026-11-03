# SIEM Telemetry Pipeline - Path 2: Modern Lightweight Stack

Target hardware: ThinkPad X280 class (Intel 8th-gen quad-core, 16 GB RAM, integrated graphics).
Architecture: Suricata / Zeek -> Vector (Rust) -> Grafana Loki -> Grafana.
Goal: Deep network visibility with total runtime footprint under ~1.5 GB RAM and minimal JVM overhead.

Wazuh is a separate endpoint-security stack on this host. See
[Wazuh Single-Node Setup and Recovery](./Wazuh_Installation_and_Recovery.md)
for its credentials, ports, installation notes, and Dashboard recovery steps.

## 1. Overview and Architecture

### 1.1 Why Path 2

| Path | Primary Storage | Primary UI | RAM Footprint | Best For |
|---|---|---|---|---|
| 1 ELK | Elasticsearch | Kibana | High (JVM 2-4 GB) | Deep ECS threat hunting |
| 2 Vector+Loki | Loki | Grafana | Low (<1.5 GB) | Lab/edge, unified UI |
| 3 Hybrid | ES + Loki | Kibana + Grafana | Medium-High | Tiered alerts vs bulk |
| 4 Minimalist | Loki | Grafana | Very Low | Constrained edge nodes |

Path 2 removes Elasticsearch/Kibana Java overhead. Vector (Rust) ingests and parses logs; Loki indexes labels only; Grafana visualizes security events and host metrics in one pane.

### 1.2 Data Flow

Network Interface -> Suricata (eve.json) + Zeek (JSON logs) -> Vector (VRL parse) -> Grafana Loki (label-indexed) -> Grafana (dashboards + alerts).

### 1.3 Component Roles

- Suricata: multi-threaded signature IDS; emits eve.json (alerts, http, dns, tls, flow, anomaly).
- Zeek: behavioral/protocol analyzer; emits structured conn, dns, http, tls, ssl, notice logs.
- Vector: ultra-fast Rust log shipper; tails files, parses JSON via VRL, transforms, pushes to Loki.
- Loki: log aggregation engine; indexes labels (job, sensor, event_type), stores chunks on disk.
- Grafana: visualization + alerting; LogQL queries against Loki.

### 1.4 Resource Budget (target)

| Process | Typical RAM | Notes |
|---|---|---|
| Suricata | 300-600 MB | depends on ruleset size |
| Zeek | 150-400 MB | depends on traffic volume |
| Vector | 50-150 MB | Rust, tiny footprint |
| Loki | 200-400 MB | single-node, TSDB |
| Grafana | 100-200 MB | |
| Total | ~1.0-1.8 GB | Leaves headroom on 16 GB |

## 2. Prerequisites

### 2.1 OS and Tooling (Arch Linux primary; Debian notes in section 10)

sudo pacman -Syu
sudo pacman -S --needed suricata zeek vector loki grafana jq curl wget git

Zeek/Suricata may need AUR on some Arch setups (yay -S zeek suricata). Verify with pacman -Qi.

### 2.2 Kernel / Capture Tuning

sudo ip link set eth0 promisc on
echo 'fs.inotify.max_user_watches = 524288' | sudo tee /etc/sysctl.d/99-siem.conf
echo 'fs.file-max = 2097152' | sudo tee -a /etc/sysctl.d/99-siem.conf
sudo sysctl --system

### 2.3 User and Permissions

sudo groupadd -f siem
sudo usermod -aG siem suricata 2>/dev/null || true
sudo usermod -aG siem zeek 2>/dev/null || true
sudo usermod -aG siem vector 2>/dev/null || true
sudo usermod -aG siem loki 2>/dev/null || true
sudo mkdir -p /var/log/suricata /var/log/zeek/current /var/lib/loki /var/lib/vector
sudo chown -R suricata:siem /var/log/suricata
sudo chown -R zeek:siem /var/log/zeek
sudo chown -R vector:vector /var/lib/vector
sudo chown -R loki:loki /var/lib/loki
sudo chmod 750 /var/log/suricata /var/log/zeek /var/lib/loki /var/lib/vector

### 2.4 Firewall Ports

Vector API (optional) 8686, Loki HTTP 3100, Loki gRPC 9096, Grafana 3000.

## 3. Installation

### 3.1 Suricata

sudo pacman -S suricata
suricata --version
sudo suricata-update

### 3.2 Zeek

yay -S zeek
zeek --version

### 3.3 Vector

sudo pacman -S vector
vector --version
vector validate /etc/vector/vector.toml

### 3.4 Loki

sudo pacman -S loki
loki --version

### 3.5 Grafana

sudo pacman -S grafana
grafana --version
## 4. Configuration

All config files live in docs/configs/ of this repo and can be copied directly.

### 4.1 Zeek - JSON Logging + Standalone Node

/etc/zeek/node.cfg:

[zeek]
type=standalone
host=localhost
interface=eth0

Enable JSON output. Add to site script (e.g. /usr/share/zeek/site/local.zeek):

@load base/frameworks/logging
redef LogAscii::use_json = T;

Deploy:

sudo zeekctl deploy
sudo zeekctl status
ls -la /var/log/zeek/current/
head -c 300 /var/log/zeek/current/conn.log

### 4.2 Suricata - eve.json Output

Key sections of /etc/suricata/suricata.yaml:

vars:
  address-groups:
    HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
    EXTERNAL_NET: "!$HOME_NET"

default-log-dir: /var/log/suricata/

outputs:
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - anomaly
        - http
        - dns
        - tls
        - flow

af-packet:
  - interface: eth0
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

Validate and start:

sudo suricata -T -c /etc/suricata/suricata.yaml
sudo systemctl enable --now suricata
sudo tail -f /var/log/suricata/eve.json

### 4.3 Vector - Ingest, Parse, Ship to Loki

/etc/vector/vector.toml (full file in docs/configs/vector.toml):

data_dir = "/var/lib/vector"

[sources.suricata_eve]
type = "file"
include = ["/var/log/suricata/eve.json"]
read_from = "end"
fingerprint.strategy = "device_and_inode"

[sources.zeek_logs]
type = "file"
include = ["/var/log/zeek/current/*.log"]
read_from = "end"
fingerprint.strategy = "device_and_inode"

[transforms.parse_suricata]
type = "remap"
inputs = ["suricata_eve"]
source = '''
. = parse_json!(.message)
.sensor = "suricata"
'''

[transforms.parse_zeek]
type = "remap"
inputs = ["zeek_logs"]
source = '''
. = parse_json!(.message)
.sensor = "zeek"
.event_type = ._path
'''

## 5. Service Enablement and Startup Order

sudo systemctl enable --now loki grafana
sudo systemctl enable --now suricata
sudo zeekctl deploy
sudo systemctl enable --now vector

systemctl is-active loki grafana suricata vector

Startup order matters: Loki must be up before Vector (Vector healthchecks Loki). Suricata/Zeek must be writing logs before Vector tails them (Vector handles missing files gracefully).

## 6. Verification Checklist

### 6.1 Layer Health

curl -s http://localhost:3100/ready && echo
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/api/health
systemctl is-active suricata
sudo tail -n 1 /var/log/suricata/eve.json | jq .
sudo zeekctl status
head -c 200 /var/log/zeek/current/conn.log
vector validate /etc/vector/vector.toml
systemctl is-active vector
sudo journalctl -u vector --no-pager -n 20

### 6.2 Loki Streams

curl -s 'http://localhost:3100/loki/api/v1/label/sensor/values' | jq .
curl -s 'http://localhost:3100/loki/api/v1/label/job/values' | jq .

curl -sG 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="siem",sensor="sensor-suricata"}' \
  --data-urlencode 'limit=5' | jq '.data.result | length'

### 6.3 Sample LogQL (in Grafana Explore)

{job="siem",sensor="sensor-suricata",event_type="evt-alert"}
{job="siem",sensor="sensor-zeek"} | json | event_type="dns"
sum by (id_orig_h) (count_over_time({job="siem",sensor="sensor-zeek"}[5m]))

### 6.4 End-to-End Test

curl -s http://example.com >/dev/null
ping -c 3 8.8.8.8

curl -sG 'http://localhost:3100/loki/api/v1/query_range' \
  --data-urlencode 'query={job="siem"}' --data-urlencode 'limit=10' | jq '.data.result[].values | length'

## 7. Dashboard Setup (Grafana)

Recommended panels:
1. Suricata Alerts Table - LogQL {job="siem",sensor="sensor-suricata",event_type="evt-alert"} -> table with timestamp, src_ip, dest_ip, alert.signature, alert.severity.
2. Zeek DNS Queries - {job="siem",sensor="sensor-zeek"} | json | event_type="dns" -> query, answers.
3. Zeek HTTP Transactions - filter event_type="http" -> host, uri, method.
4. TLS Handshakes / JA3 - event_type="ssl" -> server_name, ja3.
5. Event Rate - rate({job="siem"}[1m]) stat panel.
6. System Metrics (optional) - if node_exporter added, CPU/RAM/disk panels.

Import community dashboards from grafana.com for Suricata and Zeek Loki dashboards.

## 8. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Vector file not found | Log path not created yet | Start sensors first; Vector retries |
| Loki rejects old samples | reject_old_samples + clock skew | Sync NTP; or set reject_old_samples false temporarily |
| No Zeek logs | Wrong interface / no traffic | Check node.cfg interface; zeekctl status |
| Suricata no alerts | Rules not loaded | Run suricata-update; check rule-files in yaml |
| Disk fills up | No retention | Set retention_period in Loki; rotate Suricata logs |
| Permission denied reading logs | Group mismatch | Re-apply section 2.3 chown/chmod |
| Grafana cannot reach Loki | Wrong URL / Loki down | Verify curl localhost:3100/ready |

Diagnose a failing shipper:
sudo journalctl -u vector --no-pager -n 50
sudo vector validate /etc/vector/vector.toml
ls -la /var/log/suricata/eve.json /var/log/zeek/current/

Always validate config before restart: vector validate.

## 9. Retention and Resource Tuning

- Loki: retention_period 168h (7 days). Lower to 72h on small disks. Enable compactor (section 4.4).
- Suricata logs: rotate with logrotate daily, keep 7. Use copytruncate.
- Zeek logs: Zeek rotates hourly into /var/log/zeek/<date>/; Vector glob /var/log/zeek/current/*.log follows current hour. For historical replay, add older dirs to Vector include.
- Vector buffering: defaults to disk buffer; cap with buffer.max_size if disk tight.
- Suricata threads: tune af-packet.threads to CPU count (X280 = 4 cores -> 2-4 threads).

## 10. Debian / Ubuntu Notes

sudo apt install suricata
sudo suricata-update

Zeek via official repo (download.opensuse.org security:zeek). Vector via timber.io deb script. Loki and Grafana via apt.

Paths are identical (/etc/..., /var/log/...). Service names are the same.

## 11. Optional: Add Host Metrics (Prometheus + node_exporter)

sudo pacman -S prometheus node_exporter
sudo systemctl enable --now prometheus node_exporter

Add Prometheus datasource in Grafana (http://localhost:9090), then build panels for CPU/RAM/disk alongside LogQL panels.

## 12. Alternative Sensors

- Snort 3 can replace Suricata. Config lives in /etc/snort/snort.lua. Output alerts to a JSON file and add a Vector source for it; rest of pipeline unchanged.
- Path 1 (ELK): swap Vector sink to Elasticsearch and add Kibana. Heavier but gives ECS + ML.
- Path 3 (Hybrid): add a second Vector sink to Elasticsearch for event_type="alert" only, keeping bulk conn logs in Loki.

## 13. Appendix - Quick Reference

| Task | Command |
|---|---|
| Validate Vector | vector validate /etc/vector/vector.toml |
| Validate Suricata | suricata -T -c /etc/suricata/suricata.yaml |
| Loki readiness | curl localhost:3100/ready |
| Zeek status | zeekctl status |
| Restart pipeline | sudo systemctl restart loki vector suricata |
| View Suricata alerts | jq 'select(.event_type=="alert")' /var/log/suricata/eve.json |

Generated for the SIEM project. Adapt interface names (eth0/wlan0) and HOME_NET to your environment before deploying.

[sinks.loki_out]
type = "loki"
inputs = ["parse_suricata", "parse_zeek"]
endpoint = "http://localhost:3100"
encoding.codec = "json"
healthcheck = true

[sinks.loki_out.labels]
job = "siem"
sensor = "sensor-{{ .sensor }}"
event_type = "evt-{{ .event_type }}"

`read_from = "end"` starts with new events and avoids replaying large existing sensor logs on first start. Change it to `"beginning"` only when historical backfill is intended and Loki has enough free disk space.

The `sensor-` and `evt-` literal prefixes are required by Vector's Loki label-template confinement check. Sensor labels therefore appear as `sensor-suricata` or `sensor-zeek`, and event-type labels as `evt-alert`, `evt-dns`, and so on; use those prefixed values in label selectors.

Validate:

sudo vector validate /etc/vector/vector.toml
sudo systemctl enable --now vector
sudo journalctl -u vector -f

### 4.4 Loki - Single Node, Filesystem Storage

/etc/loki/loki.yaml (full file in docs/configs/loki.yaml):

auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /var/lib/loki
  storage:
    filesystem:
      chunks_directory: /var/lib/loki/chunks
      rules_directory: /var/lib/loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 168h
  max_query_length: 721h
  reject_old_samples: true
  reject_old_samples_max_age: 168h

compactor:
  working_directory: /var/lib/loki/compactor
  compaction_interval: 10m
  retention_enabled: true
  retention_delete_delay: 2h
  delete_request_store: filesystem

Start:

sudo systemctl enable --now loki
curl -s http://localhost:3100/ready

### 4.5 Grafana - Datasource + Dashboards

sudo systemctl enable --now grafana

Open http://localhost:3000 (default admin/admin, change on first login).

Add Loki datasource: Configuration -> Data Sources -> Add -> Loki -> URL http://localhost:3100 -> Save and Test.

Provisioning (optional, repeatable): drop a datasource YAML into /etc/grafana/provisioning/datasources/loki.yaml:

apiVersion: 1
datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://localhost:3100
    isDefault: true
    jsonData:
      maxLines: 1000

Restart Grafana after provisioning.
