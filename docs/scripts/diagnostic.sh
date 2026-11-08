# 1) Service state
sudo systemctl --no-pager status wazuh-indexer wazuh-manager wazuh-dashboard filebeat

# 2) Active Filebeat command and config
sudo systemctl show filebeat -p ExecStart --no-pager
sudo grep -nE 'output\.elasticsearch:|hosts:|index:|setup\.template|setup\.ilm|filebeat\.modules|module: wazuh|wazuh-template|pattern:' /etc/filebeat/filebeat.yml

# 3) Validate config without changing anything
sudo filebeat test config -c /etc/filebeat/filebeat.yml

# 4) Test the actual Filebeat output connection to the Indexer
sudo filebeat test output -c /etc/filebeat/filebeat.yml

# 5) Check Wazuh alert indices, prompted for admin password interactively
curl -skS -u admin 'https://127.0.0.1:9200/_cat/indices?v'
curl -skS -u admin 'https://127.0.0.1:9200/_cat/indices/wazuh-alerts-*?v'

# 6) Check Wazuh templates in the Indexer
curl -skS -u admin 'https://127.0.0.1:9200/_template/wazuh?pretty' | head -c 2000
curl -skS -u admin 'https://127.0.0.1:9200/_index_template?pretty' | grep -i -A 8 -B 3 wazuh

# 7) Verify the security health endpoint
curl -skS 'https://127.0.0.1:9200/_plugins/_security/health'

# 8) Review recent Wazuh/Filebeat logs
sudo journalctl -u filebeat --since '30 minutes ago' --no-pager -o cat | tail -n 80
sudo journalctl -u wazuh-dashboard --since '30 minutes ago' --no-pager -o cat | tail -n 80
sudo journalctl -u wazuh-indexer --since '30 minutes ago' --no-pager -o cat | grep -Ei 'error|exception|denied|security|SSL|kibana' | tail -n 80
sudo tail -n 80 /var/ossec/logs/ossec.log


# Revised Diagnostics
sudo systemctl show filebeat -p ActiveState -p NRestarts -p ExecStart --no-pager
sudo journalctl -u filebeat --since '30 minutes ago' --no-pager -o cat | grep -Ei 'pthread_create|fatal|panic|failed|unauthorized|401|connection refused' | tail -n 60
sudo grep -nE 'output\.elasticsearch:|hosts:|index:|setup\.template|wazuh-template|filebeat\.modules|module: wazuh' /etc/filebeat/filebeat.yml
sudo filebeat test config -c /etc/filebeat/filebeat.yml
sudo filebeat test output -c /etc/filebeat/filebeat.yml
sudo grep -nE '<(localfile|location|log_format|syscheck|disabled|directories)>' /var/ossec/etc/ossec.conf | head -n 100
sudo /var/ossec/bin/agent_control -l
curl -skS -u admin 'https://127.0.0.1:9200/_cat/indices/wazuh-alerts-*?v'
curl -skS -u admin 'https://127.0.0.1:9200/_index_template?pretty' | grep -i -A 8 -B 3 wazuh