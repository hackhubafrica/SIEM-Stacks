INFO: Index pattern id in cookie: yes [wazuh-alerts-*]
INFO: Getting list of valid index patterns...
INFO: Valid index patterns found: 1
INFO: Found default index pattern with title [wazuh-alerts-*]: yes
INFO: Checking the app default pattern exists: id [wazuh-alerts-*]...
INFO: Default pattern with id [wazuh-alerts-*] exists: yes
ACTION: Default pattern id [wazuh-alerts-*] set as default index pattern
INFO: Checking the index pattern id [wazuh-alerts-*] exists...
INFO: Index pattern id exists [wazuh-alerts-*]: yes
INFO: Index pattern id in cookie: yes [wazuh-alerts-*]
INFO: Checking if the index pattern id [wazuh-alerts-*] exists...
INFO: Index pattern id [wazuh-alerts-*] found: yes title [wazuh-alerts-*]
INFO: Checking if exists a template compatible with the index pattern title [wazuh-alerts-*]
INFO: Template found for the selected index-pattern title [wazuh-alerts-*]: no
ERROR: No template found for the selected index-pattern title [wazuh-alerts-*]
INFO: Index pattern id in cookie: [wazuh-alerts-*]
INFO: Getting index pattern data [wazuh-alerts-*]...
INFO: Index pattern data found: [yes]
INFO: Refreshing index pattern fields: title [wazuh-alerts-*], id [wazuh-alerts-*]...
WARNING: Index pattern fields for title [wazuh-alerts-*], id [wazuh-alerts-*] could not be refreshed due to: No matching indices found: No indices match pattern "wazuh-alerts-*". This could be an indicator of some problem in the generation, not running server service or configuration to ingest of alerts data.
INFO: Getting settings...
INFO: Check dashboard setting [timeline:max_buckets]: 200000
INFO: App setting [timeline:max_buckets]: 200000
INFO: Settings mismatch [timeline:max_buckets]: no
INFO: Getting settings...
INFO: Check dashboard setting [metaFields]: ["_source","_index"]
INFO: App setting [metaFields]: ["_source","_index"]
INFO: Settings mismatch [metaFields]: no
INFO: Getting settings...
INFO: Check dashboard setting [timepicker:timeDefaults]: {"from":"now-24h","to":"now"}
INFO: App setting [timepicker:timeDefaults]: "{\"from\":\"now-24h\",\"to\":\"now\"}"
INFO: Settings mismatch [timepicker:timeDefaults]: no