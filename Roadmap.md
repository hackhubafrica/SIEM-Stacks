## Plan to Actually Deploy & Verify on This Machine (Path 2)

Switch to __Act mode__ and I'll execute these phases, validating each:

__Phase 1 — Rules & Sensors__

1. `sudo suricata-update` (Emerging Threats Open) → verify `/var/lib/suricata/rules/` populated.
2. Enable Zeek JSON logging (`LogAscii::use_json = T` in site script), set interface in `node.cfg` (currently `wlan0` — confirm correct interface), `sudo zeekctl deploy`.
3. Validate: `suricata -T`, `zeekctl status`, sample JSON lines in `/var/log/suricata/eve.json` and `/var/log/zeek/current/*.log`.

__Phase 2 — Consolidate Ingestion (avoid duplicates)__ 4. Make `/etc/vector/vector.toml` the active Vector config (currently Vector may be loading `vector.yaml` demo config); remove/disable the dummy `demo_logs` source. 5. Decide: keep Promtail for Zeek (and drop Vector's zeek source) OR keep Vector for both and disable Promtail. Recommended: __Vector for both__, disable Promtail to avoid duplicate Loki streams. 6. Disable the crashing Filebeat service (`systemctl disable --now filebeat`) since Path 2 doesn't use ES.

__Phase 3 — Start & Verify__ 7. Restart Loki → Vector → Suricata → Zeek in dependency order. 8. Run `docs/scripts/verify.sh`: Loki ready, Grafana health, service states, Loki label values, Vector validation. 9. Generate benign traffic (`curl example.com`, `ping`), confirm events land in Loki within ~30s via LogQL.

__Phase 4 — Grafana__ 10. Add Loki datasource (if not present), import Suricata/Zeek dashboards, build alert panels.

__Phase 5 — Snort (optional)__ 11. If desired, point a Vector source at Snort's JSON alert log.

### Clarifying Questions Before Executing

1. Which interface should Suricata and Zeek capture on — `eth0`, `wlan0`, or both? (Currently split: Zeek on wlan0, Suricata on eth0.)
2. Keep Promtail or consolidate fully on Vector?
3. Should I disable Filebeat (it's currently failing and unused in Path 2)?
