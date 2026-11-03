#!/usr/bin/env bash
# Switch Suricata + Zeek capture interface.
# Usage: sudo ./switch_iface.sh wlan0   (or eth0)
set -euo pipefail

IFACE="${1:-}"
if [[ -z "$IFACE" ]]; then
  echo "Usage: $0 <interface>  (e.g. wlan0 or eth0)" >&2
  exit 1
fi

SURICATA_YAML="/etc/suricata/suricata.yaml"
ZEEK_NODE="/etc/zeek/node.cfg"

# Suricata: replace af-packet and pcap interface lines
sudo sed -i "s/^\(\s*\)- interface: eth0/\1- interface: ${IFACE}/" "$SURICATA_YAML"
sudo sed -i "s/^\(\s*\)- interface: wlan0/\1- interface: ${IFACE}/" "$SURICATA_YAML"
# Catch any remaining interface: <name> lines that are active (not commented)
sudo sed -i -E "s/^(\s*- interface:) (eth0|wlan0|enp[0-9a-z]+)$/\1 ${IFACE}/" "$SURICATA_YAML"

# Zeek node.cfg
sudo sed -i "s/^interface=.*/interface=${IFACE}/" "$ZEEK_NODE"

echo "Switched capture interface to: ${IFACE}"
echo "  Suricata: $SURICATA_YAML"
echo "  Zeek:     $ZEEK_NODE"
echo "Restart services: sudo systemctl restart suricata && sudo zeekctl deploy"
