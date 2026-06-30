#!/bin/bash

# ==============================================================================
# SCRIPT: configures_fluent-bit.sh
# DESCRIPTION: Automates the configuration of Fluent-bit on the host system.
# ==============================================================================

set -e

# Define the default Fluent Bit configuration directory on the Host machine
CONFIG_DIR="/etc/fluent-bit"

echo "===================================================="
echo ">>> Starting Fluent Bit Pipeline configuration..."
echo "===================================================="

# 1. Backup the default configuration to prevent data loss
if [ -f "$CONFIG_DIR/fluent-bit.conf" ] && [ ! -f "$CONFIG_DIR/fluent-bit.conf.bak" ]; then
    echo ">>> Backing up the default configuration to $CONFIG_DIR/fluent-bit.conf.bak"
    sudo cp "$CONFIG_DIR/fluent-bit.conf" "$CONFIG_DIR/fluent-bit.conf.bak"
fi

# 2. Overwrite the main configuration file (fluent-bit.conf)
echo ">>> Initializing main configuration: fluent-bit.conf"
sudo cat > "$CONFIG_DIR/fluent-bit.conf" << 'EOF'
[SERVICE]
    Flush         5
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

# -------------------------------------------------------------------
# INPUT: Data Log Collection
# -------------------------------------------------------------------
# 1. System Authentication Log (For AI SSH/Auth behavior analysis)
[INPUT]
    Name              tail
    Path              /var/log/auth.log
    Tag               system.auth
    Parser            syslog
    Refresh_Interval  5
    Mem_Buf_Limit     20MB
    Skip_Long_Lines   On

# 2. Centralized Alert Logs from Wazuh Manager
[INPUT]
    Name              tail
    Path              /var/ossec/logs/alerts/alerts.json
    Tag               wazuh.alerts
    Parser            json
    Refresh_Interval  5
    Mem_Buf_Limit     50MB
    Skip_Long_Lines   On

# -------------------------------------------------------------------
# FILTER: Data Normalization and Metadata Tagging
# -------------------------------------------------------------------
[FILTER]
    Name    record_modifier
    Match   *
    Record  agent_host wazuh.manager

# -------------------------------------------------------------------
# OUTPUT: Data Distribution to Targets
# -------------------------------------------------------------------
# TARGET 1: Forward to AI Node Service (Python Machine Learning Application)
[OUTPUT]
    Name        http
    Match       *
    Host        ai-anomaly-detector  # Hostname or IP of the machine running the AI model
    Port        5000                 # Python service port listening for logs
    URI         /api/logs
    Format      json

# TARGET 2: Push raw Wazuh alert logs to Grafana Loki cluster
[OUTPUT]
    Name        loki
    Match       wazuh.alerts
    Host        loki                 # Hostname or IP of the Grafana Loki container
    Port        3100
    Labels      job=wazuh_alerts, host=wazuh.manager
    Line_Format json

# TARGET 3: Push raw System Auth logs to Grafana Loki cluster
[OUTPUT]
    Name        loki
    Match       system.auth
    Host        loki
    Port        3100
    Labels      job=system_auth, host=wazuh.manager
    Line_Format json
EOF

# 3. Overwrite the data parser definition file (parsers.conf)
echo ">>> Initializing parser definitions: parsers.conf"
sudo cat > "$CONFIG_DIR/parsers.conf" << 'EOF'
[PARSER]
    Name        json
    Format      json
    Time_Key    timestamp
    Time_Format %Y-%m-%dT%H:%M:%S.%L%z

[PARSER]
    Name        syslog
    Format      regex
    Regex       ^(?<time>[^ ]* {1,2}[^ ]* [^ ]*) (?<host>[^ ]*) (?<ident>[a-zA-Z0-9_\/\.\-]*)(?:\[(?<pid>[0-9]*)\])?(?:[^\:]*\:)? *(?<message>.*)$
    Time_Key    time
    Time_Format %b %d %H:%M:%S
EOF

# 4. Restart the service to apply the new configuration pipeline
echo ">>> Applying configuration and restarting Fluent Bit service..."
sudo systemctl restart fluent-bit

echo "===================================================="
echo ">>> Configuration completed successfully!"
echo "===================================================="
