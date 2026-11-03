# Wazuh Single-Node Setup and Recovery Guide

This runbook documents the Wazuh all-in-one installation on this Arch Linux host,
the Dashboard/Indexer recovery that was performed, and a repeatable checklist
for future installations. It is intentionally separate from the Vector/Loki
Suricata and Zeek pipeline: they are different stacks and use different ports,
credentials, and storage.

> **Version and platform note:** This host reported Wazuh Manager, Indexer, and
> Dashboard `4.14.9`, with Wazuh Indexer based on OpenSearch and a Filebeat
> package. Wazuh's documented installation procedures target supported
> distributions such as Ubuntu and RHEL-family systems. Arch packages may be
> community-maintained; for a repeatable production-like installation, use a
> Wazuh-supported OS and the official installation assistant or official
> package instructions. Confirm commands against the documentation for the
> exact Wazuh release being installed.

## 1. What runs in this setup

```text
Wazuh agents -> Wazuh Manager -> Wazuh Indexer -> Wazuh Dashboard (HTTPS)
                                      ^
                                      |
                         Filebeat (alert shipping,
                         where configured by this release)
```

Wazuh is separate from the project's other stack:

```text
Suricata / Zeek -> Vector -> Loki -> Grafana
```

Do not point the Wazuh Dashboard at the standalone Elasticsearch service or at
Loki. The Wazuh Dashboard should connect to the **Wazuh Indexer**, not the
unrelated Elasticsearch service.

### Services and local ports

| Component | Service | Typical local port | Purpose |
|---|---|---:|---|
| Wazuh Indexer | `wazuh-indexer` | TCP 9200, HTTPS | Search and alert/state storage |
| Wazuh Dashboard | `wazuh-dashboard` | TCP 443, HTTPS | Web interface |
| Wazuh Manager API | `wazuh-manager` | TCP 55000, HTTPS | Dashboard-to-manager API |
| Wazuh agent enrollment | `wazuh-manager` | TCP 1515 | Agent enrollment |
| Wazuh agent events | `wazuh-manager` | TCP/UDP 1514, as configured | Agent communication |
| Filebeat | `filebeat` | Outbound to Indexer | Alert shipping when enabled in the installation |

This machine also has other services that may use Elasticsearch-compatible
ports, including a separate Elasticsearch instance on `9201`. Confirm the
listener and service before using any port. Keep Indexer and Manager ports
firewalled from untrusted networks.

## 2. Wazuh usernames and passwords

There is **no universal current Wazuh password** that should be assumed for a
fresh installation. Installers may generate a password and print or save it in
an installer output/archive. Retrieve that generated credential from the
installation record or reset it with the Wazuh password tool. Do not rely on
old online examples such as `admin` / `SecretPassword`.

| Username | Used for | Notes |
|---|---|---|
| `admin` | Human login to the Wazuh Dashboard; Indexer administrator | Common default username. The password is installation-generated or subsequently changed. |
| `kibanaserver` | Dashboard service account to the Indexer | Not a human Dashboard login. Its password must match the Dashboard keystore entry `opensearch.password`. |
| `wazuh` | Wazuh Manager API administrator | Separate from Indexer `admin`. |
| `wazuh-wui` | Dashboard service account to the Manager API | Separate from `kibanaserver`; its password is configured in the Wazuh Dashboard app integration. |

Password changes have dependencies. Changing the Indexer `admin` account can
require updating Filebeat and the Manager Indexer keystore. Changing
`kibanaserver` requires updating the Dashboard keystore. Changing `wazuh-wui`
requires updating the Dashboard's Wazuh API integration. Avoid changing every
account at once when troubleshooting one component.

Keep generated credentials in a password manager. Never commit them to this
repository or paste them into shared logs. Avoid literal passwords in command
arguments, shell history, and process listings.

## 3. Fresh installation outline

Use the official Wazuh installation guide for a clean installation. The
following is the order of operations, not a substitute for the release-specific
official package instructions.

1. **Prepare the host.**
   - Use a supported Linux distribution and a clean, adequately sized disk.
   - Set a stable hostname and local address.
   - Check available RAM, disk space, DNS, NTP/time synchronization, and firewall
     policy.
   - Do not install multiple competing Indexers/Search backends for one Wazuh
     Dashboard.
2. **Create the Wazuh certificates.**
   - Use the release-matched Wazuh certificate tool and its configuration file.
   - Define the exact Indexer node name and IP/DNS name, Manager server name,
     and Dashboard name/address.
   - Keep the generated certificate archive private; it contains private keys.
   - Deploy the matching node certificates and CA to each component, then set
     ownership and restrictive permissions as shown in the official guide.
3. **Configure and start the Indexer.**
   - Set the node name, cluster name, data path, certificates, admin
     distinguished name, and node distinguished name.
   - Start the Indexer and initialize its security configuration **once** with
     the release's `indexer-security-init.sh`.
   - Do not rerun initialization on a working cluster as a generic repair; it
     can overwrite security configuration.
4. **Install/configure the Manager.**
   - Set its Indexer destination to the Indexer's reachable HTTPS address (on
     this single host, `https://127.0.0.1:9200`), never `0.0.0.0`.
   - Configure the correct CA and the Manager's client certificate/key as
     required by the installed version.
   - Configure the Manager API and secure its credentials.
5. **Install/configure the Dashboard.**
   - Point `opensearch.hosts` to the Wazuh Indexer HTTPS address.
   - Configure the Indexer CA and the `kibanaserver` service account.
   - Configure the Manager API integration with its HTTPS address, API
     credentials, and `run_as` setting as appropriate.
6. **Configure alert shipping.**
   - Follow the release's Filebeat setup if it is part of the installed
     architecture. Check the service and its output/authentication rather than
     assuming an active unit means it is working.
7. **Verify each hop before opening the UI.**
   - Indexer security endpoint and cluster health.
   - Manager API response.
   - Manager-to-Indexer connector.
   - Dashboard-to-Indexer readiness.
   - Agent enrollment/event receipt, where agents are configured.

Official references:

- [Wazuh Indexer installation and cluster initialization](https://documentation.wazuh.com/current/installation-guide/wazuh-indexer/step-by-step.html)
- [Wazuh Dashboard installation](https://documentation.wazuh.com/current/installation-guide/wazuh-dashboard/step-by-step.html)
- [Wazuh password management](https://documentation.wazuh.com/current/user-manual/user-administration/password-management.html)
- [Wazuh ports and network requirements](https://documentation.wazuh.com/current/getting-started/architecture.html#required-ports)

## 4. Configuration values for this single-node host

The observed Dashboard configuration after repair uses:

```yaml
server.host: 0.0.0.0
server.port: 443
opensearch.hosts: ["https://127.0.0.1:9200"]
opensearch.ssl.verificationMode: certificate
opensearch.username: kibanaserver
opensearch.ssl.certificateAuthorities:
  - "/etc/wazuh-dashboard/certs/root-ca.pem"
```

The Dashboard's `opensearch.password` belongs in the Dashboard keystore, not in
this YAML file. Its TLS certificate and private key are configured separately
with `server.ssl.certificate` and `server.ssl.key`.

The Manager Indexer destination on this single-node host was corrected from
`https://0.0.0.0:9200` to:

```xml
<host>https://127.0.0.1:9200</host>
```

`0.0.0.0` is a bind address, not a destination address. Before using these
values on another machine, replace loopback addresses with the correct
reachable hostnames/IPs and matching certificates.

## 5. Dashboard says “Wazuh dashboard server is not ready yet”

This message means the Dashboard's backend did not become ready; repeatedly
refreshing the browser will not repair an Indexer connection or authentication
problem.

### 5.1 Check components and endpoints

```bash
sudo systemctl --no-pager --full status \
  wazuh-indexer wazuh-manager wazuh-dashboard filebeat

# Security plugin state; HTTP 200 with status UP is expected.
curl -skS -m 15 https://127.0.0.1:9200/_plugins/_security/health

# Cluster health, authenticated with the local admin client certificate.
sudo curl -sS --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  'https://127.0.0.1:9200/_cluster/health?pretty'

# The unauthenticated Manager API should challenge with HTTP 401, not hang.
curl -skS -o /dev/null -w 'Manager API HTTP %{http_code}\n' \
  https://127.0.0.1:55000/

# Capture recent component logs.
sudo journalctl -u wazuh-dashboard --since '10 minutes ago' --no-pager -o cat | tail -n 100
sudo journalctl -u wazuh-indexer --since '10 minutes ago' --no-pager -o cat | \
  grep -Ei 'error|exception|denied|security|SSL' | tail -n 60
sudo tail -n 100 /var/ossec/logs/ossec.log | \
  grep -Ei 'indexer-connector|error|warn|connected|failed' | tail -n 60
```

An unauthenticated Indexer HTTP 401 is normal when security is initialized; it
does not prove that the Dashboard service account is valid. A green cluster
health also does not by itself prove the Dashboard can authenticate.

### 5.2 Resynchronize only the Dashboard's `kibanaserver` credential

Use this only when the Indexer is healthy but the Dashboard continues to log
OpenSearch `ResponseError` messages. The procedure below:

- backs up the current Dashboard keystore,
- sets a fresh password for only `kibanaserver`,
- stores it in the Dashboard keystore without printing it,
- verifies that account against the Indexer, and
- restarts the Dashboard only if authentication succeeds.

Run it in a terminal as written:

```bash
sudo bash <<'EOF'
set -euo pipefail

password_tool=/usr/share/wazuh-indexer/plugins/opensearch-security/tools/wazuh-passwords-tool.sh
keystore=/etc/wazuh-dashboard/opensearch_dashboards.keystore
backup="/root/opensearch_dashboards.keystore.backup-$(date +%Y%m%d-%H%M%S)"
auth_cfg=''
password_file=''
pass="$(openssl rand -hex 16)Aa?1"
cleanup() {
  [[ -z "$auth_cfg" ]] || rm -f -- "$auth_cfg"
  [[ -z "$password_file" ]] || rm -f -- "$password_file"
  unset pass
}
trap cleanup EXIT

install -o root -g root -m 600 "$keystore" "$backup"
password_file=$(mktemp /run/wazuh-kibanaserver-password.XXXXXX)
chmod 600 "$password_file"
printf 'indexer_username: kibanaserver\nindexer_password: %s\n' "$pass" > "$password_file"
"$password_tool" -f "$password_file" >/dev/null 2>&1
rm -f -- "$password_file"
password_file=''

printf '%s' "$pass" | /usr/share/wazuh-dashboard/bin/opensearch-dashboards-keystore \
  --allow-root add -f --stdin opensearch.password
chown wazuh-dashboard:wazuh-dashboard "$keystore"
chmod 600 "$keystore"

auth_cfg=$(mktemp /run/wazuh-dashboard-auth.XXXXXX)
chmod 600 "$auth_cfg"
printf 'user = "kibanaserver:%s"\n' "$pass" > "$auth_cfg"
http_code=$(curl -sS --cacert /etc/wazuh-dashboard/certs/root-ca.pem \
  --config "$auth_cfg" -o /dev/null -w '%{http_code}' \
  https://127.0.0.1:9200/_plugins/_security/api/account)
rm -f -- "$auth_cfg"
auth_cfg=''
unset pass

printf 'kibanaserver authentication HTTP %s (expected 200)\n' "$http_code"
if [[ "$http_code" != 200 ]]; then
  echo 'Authentication failed; do not restart the Dashboard. Inspect the Indexer logs.'
  exit 1
fi

systemctl restart wazuh-dashboard
sleep 10
curl -k -sS -o /dev/null -w 'Dashboard status HTTP %{http_code}\n' \
  https://127.0.0.1/api/status
EOF
```

The account endpoint should return HTTP 200. Dashboard `/api/status` may return
HTTP 401 when unauthenticated even after it is ready; distinguish that from the
plain-text HTTP 503 body `Wazuh dashboard server is not ready yet`.

If authentication is HTTP 200 but Dashboard still reports 503, inspect the
fresh logs before changing another password:

```bash
sudo journalctl -u wazuh-dashboard --since '3 minutes ago' --no-pager -o cat | tail -n 80
sudo journalctl -u wazuh-indexer --since '3 minutes ago' --no-pager -o cat | \
  grep -Ei 'error|exception|denied|kibana|security|SSL' | tail -n 50
```

Do not rerun `indexer-security-init.sh` on a cluster whose security endpoint
and cluster health already succeed.

## 6. Manager-to-Indexer connection

Check the configured Manager endpoint without printing passwords:

```bash
sudo grep -nE '<(host|url|port|certificate_authorities|username)>' \
  /var/ossec/etc/ossec.conf
```

On this single host, the Indexer `<host>` should be `https://127.0.0.1:9200`.
If correcting a known incorrect target, back up first and then edit only that
host value:

```bash
sudo cp -a /var/ossec/etc/ossec.conf \
  "/var/ossec/etc/ossec.conf.backup-$(date +%Y%m%d-%H%M%S)"
sudo sed -i \
  's#<host>https://0\.0\.0\.0:9200</host>#<host>https://127.0.0.1:9200</host>#' \
  /var/ossec/etc/ossec.conf
sudo grep -n '<host>https://' /var/ossec/etc/ossec.conf
sudo systemctl restart wazuh-manager
sudo tail -n 120 /var/ossec/logs/ossec.log | \
  grep -Ei 'indexer-connector|error|warn|connected|failed' | tail -n 50
```

The Manager also needs the correct Indexer CA/client certificates and its
Indexer user credentials. Do not replace these with the Dashboard's
`kibanaserver` password.

## 7. Filebeat and alerts

This host's Filebeat unit had a large restart count and logged:

```text
runtime/cgo: pthread_create failed: Operation not permitted
```

That is distinct from Dashboard readiness. Check the actual service failure
before modifying its systemd limits or disabling it:

```bash
sudo systemctl status filebeat --no-pager --full
sudo journalctl -u filebeat --since '30 minutes ago' --no-pager -o cat | \
  grep -Ei 'error|fatal|panic|failed|pthread_create|unauthorized|401|connection refused' | \
  tail -n 60
sudo filebeat test config -c /etc/filebeat/filebeat.yml
sudo filebeat test output -c /etc/filebeat/filebeat.yml
```

Do not rotate the Indexer `admin` password until you are prepared to update
every component that uses it (including Filebeat and the Manager keystore).
Do not disable Filebeat until confirming whether this Wazuh version/setup uses
it for alert delivery.

### 7.1 Missing Wazuh alerts template or index pattern

The message `No template found for the selected index-pattern title
[wazuh-alerts-*]` means the Dashboard did not find an Indexer template matching
that requested pattern. It is not evidence that the Dashboard password is
wrong. For Wazuh 4.14.9, the shipped alerts template uses the versioned pattern
`wazuh-alerts-4.x-*`; Wazuh's Filebeat module normally writes indices with that
versioned prefix. A Dashboard pattern of `wazuh-alerts-*` matches those index
names but may not match the template title/pattern expected by the template
picker.

This project also has a separate [Filebeat example config](../filebeat-wazuh.yml)
that writes custom indices to the standalone Elasticsearch service at
`http://localhost:9201`. That is not the Wazuh Filebeat configuration and does
not install the Wazuh Indexer template. Do not copy it over
`/etc/filebeat/filebeat.yml` when the goal is to populate the Wazuh Dashboard.

First inspect the active Filebeat configuration paths, template, existing
indices, and templates. `curl -u admin` prompts for the password instead of
including it in the command line:

```bash
sudo systemctl show filebeat -p ExecStart --no-pager
sudo grep -nE 'output\\.elasticsearch:|hosts:|index:|setup\\.template|wazuh-template|filebeat\\.modules|module: wazuh' \
  /etc/filebeat/filebeat.yml
sudo filebeat test config -c /etc/filebeat/filebeat.yml
sudo filebeat test output -c /etc/filebeat/filebeat.yml

sudo curl -sk -u admin \
  'https://127.0.0.1:9200/_cat/indices/wazuh-alerts-*?v'
sudo curl -sk -u admin \
  'https://127.0.0.1:9200/_template/wazuh?pretty'
sudo curl -sk -u admin \
  'https://127.0.0.1:9200/_index_template?pretty' | grep -i -A 8 -B 3 wazuh
```

Wazuh's official server setup also specifies `/etc/filebeat/wazuh-template.json`
and the Wazuh Filebeat module. Confirm both are configured in the actual active
`/etc/filebeat/filebeat.yml`, not only in a project example. If the template is
missing, use the version-matched official Wazuh Filebeat configuration and
template instructions for the installed Wazuh version; do not install a
generic Filebeat template or point this Wazuh Filebeat output at port 9201.

For the Dashboard template picker, select the version-matched title
`wazuh-alerts-4.x-*` when it is offered. For searches and saved visualizations,
`wazuh-alerts-*` can still match versioned alert indices once they exist.
If the index query is empty, the problem is upstream (Filebeat config/output,
Filebeat service failure, or no alerts), not the Dashboard pattern. In this
installation, earlier logs showed Filebeat `pthread_create failed:
Operation not permitted`, so an `active` systemd state alone must not be taken
as proof that Filebeat is continuously sending alerts.

## 8. Routine end-to-end health checks

```bash
sudo systemctl is-active wazuh-indexer wazuh-manager wazuh-dashboard
curl -skS -m 15 https://127.0.0.1:9200/_plugins/_security/health
sudo curl -sS --cacert /etc/wazuh-indexer/certs/root-ca.pem \
  --cert /etc/wazuh-indexer/certs/admin.pem \
  --key /etc/wazuh-indexer/certs/admin-key.pem \
  'https://127.0.0.1:9200/_cluster/health?pretty'
curl -k -sS -o /dev/null -w 'Dashboard HTTP %{http_code}\n' https://127.0.0.1/
curl -skS -o /dev/null -w 'Manager API HTTP %{http_code}\n' \
  https://127.0.0.1:55000/
sudo tail -n 80 /var/ossec/logs/ossec.log | \
  grep -Ei 'indexer-connector|error|warn|connected|failed' | tail -n 30
df -h /
```

Expected:

- `wazuh-indexer`, `wazuh-manager`, and `wazuh-dashboard` are active.
- Indexer security health reports `UP`.
- Authenticated Indexer cluster health reports `green` for a healthy single
  node.
- Dashboard does not show the not-ready 503 page.
- Manager logs do not continually report IndexerConnector initialization
  retries.
- Disk has a safe amount of free space.

## 9. Backups and security practices

- Back up config files before editing them; store backups with restrictive
  permissions.
- Protect `/etc/wazuh-indexer/certs`, `/etc/wazuh-dashboard/certs`, and all
  private keys. Private keys must not be world-readable or world-writable.
- Never copy private keys into this repository.
- Restrict TCP 9200, 55000, 1514, and 1515 to the required local network/hosts.
  Bind management endpoints to loopback where possible.
- Do not delete Indexer data, initialize security again, or rotate all passwords
  as first-line troubleshooting.
- This host's root filesystem was approximately 95% full. Investigate disk use
  and configure retention/log rotation before replaying old logs or enabling
  additional search stacks:

  ```bash
  df -h /
  sudo du -xhd1 /var /home 2>/dev/null | sort -h
  ```

## 10. Notes from the repaired installation

- Wazuh Indexer security was initialized; its security health reported `UP` and
  authenticated single-node cluster health reported `green`.
- The Dashboard had been targeting the separate Elasticsearch endpoint at
  `http://localhost:9201`; it must target Wazuh Indexer at
  `https://127.0.0.1:9200`.
- Dashboard readiness was restored by synchronizing only the
  `kibanaserver` password into the Dashboard keystore and verifying its
  authentication before restarting the Dashboard.
- The Manager Indexer target was changed from `https://0.0.0.0:9200` to
  `https://127.0.0.1:9200`.
- Filebeat thread creation failures and disk pressure were observed separately;
  they require independent follow-up and should not be confused with the
  Dashboard-to-Indexer credential repair.
