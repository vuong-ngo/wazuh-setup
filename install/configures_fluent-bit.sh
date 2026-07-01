#!/bin/bash

# ==============================================================================
# SCRIPT: configure_fluent_bit.sh (Real-time Optimized < 5s)
# DESCRIPTION: Automates and optimizes Fluent Bit pipeline for sub-5s latency.
# ==============================================================================

set -e

# Define the default Fluent Bit configuration directory on the Host machine
CONFIG_DIR="/etc/fluent-bit"

echo "===================================================="
echo ">>> Starting REAL-TIME Fluent Bit Pipeline configuration..."
echo "===================================================="

# Ensure the configuration directory exists
if [ ! -d "$CONFIG_DIR" ]; then
    echo ">>> Creating configuration directory: $CONFIG_DIR"
    sudo mkdir -p "$CONFIG_DIR"
fi

# 1. Backup the default configuration to prevent data loss
if [ -f "$CONFIG_DIR/fluent-bit.conf" ] && [ ! -f "$CONFIG_DIR/fluent-bit.conf.bak" ]; then
    echo ">>> Backing up the default configuration to $CONFIG_DIR/fluent-bit.conf.bak"
    sudo cp "$CONFIG_DIR/fluent-bit.conf" "$CONFIG_DIR/fluent-bit.conf.bak"
fi

# 2. Overwrite the main configuration file (fluent-bit.conf) with real-time parameters
echo ">>> Initializing real-time configuration: fluent-bit.conf"
sudo cat > "$CONFIG_DIR/fluent-bit.conf" << 'EOF'
[SERVICE]
    # Force Fluent Bit to flush data every 1 second (Theoretical max latency is 1s)
    Flush         1
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

# -------------------------------------------------------------------
# INPUT: Real-time Log Collection via inotify
# -------------------------------------------------------------------
# 1. System Authentication Log
[INPUT]
    Name              tail
    Path              /var/log/auth.log
    Tag               system.auth
    Parser            syslog
    # Relying on native inotify events for immediate reads instead of polling interval
    Buffer_Chunk_Size 32k
    Buffer_Max_Size   64k
    Mem_Buf_Limit     20MB
    Skip_Long_Lines   On

# 2. Centralized Alert Logs from local Wazuh Manager
[INPUT]
    Name              tail
    Path              /var/ossec/logs/alerts/alerts.json
    Tag               wazuh.alerts
    Parser            json
    Buffer_Chunk_Size 64k
    Buffer_Max_Size   128k
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
# OUTPUT: Data Distribution to Targets (Immediate Streams)
# -------------------------------------------------------------------
# TARGET 1: Forward to AI Node Service (Python Machine Learning Application)
[OUTPUT]
    Name        http
    Match       *
    Host        ai-anomaly-detector  # Replace with actual IP if running on a separate host
    Port        5000
    URI         /api/logs
    Format      json

# TARGET 2: Push raw Wazuh alert logs to Grafana Loki cluster
[OUTPUT]
    Name        loki
    Match       wazuh.alerts
    Host        loki                 # Replace with actual Grafana Loki host IP/domain
    Port        3100
    Labels      job=wazuh_alerts, host=wazuh.manager
    Line_Format json

# TARGET 3: Push raw System Auth logs to Grafana Loki cluster
[OUTPUT]
    Name        loki
    Match       system.auth
    Host        loki                 # Replace with actual Grafana Loki host IP/domain
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

# 4. Restart the systemd service to apply the new pipeline configuration
echo ">>> Applying configuration and restarting Fluent Bit service..."
sudo systemctl restart fluent-bit
sudo systemctl stop fluent-bit
sudo systemctl start fluent-bit

echo "===================================================="
echo ">>> Real-time Pipeline completed successfully!"
echo "===================================================="
