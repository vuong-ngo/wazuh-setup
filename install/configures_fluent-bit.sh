#!/bin/bash
# ==============================================================================
# SCRIPT: configure_agent.sh
# DESCRIPTION: Configures log routing for the Fluent-bit agent.
# USAGE: sudo ./configure_agent.sh <SIEM_SERVER_IP>
# ==============================================================================

# Validate argument input
if [ -z "$1" ]; then
  echo "❌ Error: Missing server IP address."
  echo "USAGE: sudo ./configure_agent.sh <SIEM_SERVER_IP>"
  exit 1
fi

SERVER_IP=$1
CONFIG_FILE="/etc/fluent-bit/fluent-bit.conf"

echo "⚙️ [1/2] Configuring log pipeline to point towards: $SERVER_IP"

# Generate Fluent-bit configuration block
# Stream 1: Wazuh (Static Rule Analysis)
# Stream 2: Loki (Raw Log Retention)
cat <<EOF > $CONFIG_FILE
[SERVICE]
    Flush        1
    Log_Level    info

[INPUT]
    Name         systemd
    Systemd_Filter _SYSTEMD_UNIT=sshd.service

# Wazuh Output: For rule-based threat detection
[OUTPUT]
    Name         syslog
    Match        *
    Host         $SERVER_IP
    Port         514
    Mode         udp

# Loki Output: For raw log storage and forensic analysis
[OUTPUT]
    Name         loki
    Match        *
    Host         $SERVER_IP
    Port         3100
    Labels       job=sshd_logs
EOF

echo "🔄 [2/2] Restarting Fluent-bit to apply new settings..."
systemctl restart fluent-bit

echo "========================================================================"
echo "✅ PIPELINE CONFIGURATION COMPLETE!"
echo "Data is now streaming to Wazuh ($SERVER_IP:514) and Loki ($SERVER_IP:3100)."
echo "========================================================================"
