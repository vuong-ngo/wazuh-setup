#!/bin/bash

# ==============================================================================
# SCRIPT: install_fluent_bit.sh
# DESCRIPTION: Automates Fluent Bit installation and pipeline configuration.
# AUTHOR: Gemini Collaborator
# ==============================================================================

# --- UI COLORS ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Ensure the script is run with administrative privileges
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR: This script must be run as root (use sudo).${NC}"
   exit 1
fi

echo -e "${BLUE}====================================================${NC}"
echo -e "   🚀 STARTING FLUENT BIT DEPLOYMENT"
echo -e "${BLUE}====================================================${NC}"

# 1. Install Fluent Bit via official repository
echo -e "${GREEN}[1/3]${NC} Installing Fluent Bit package..."
curl -s https://raw.githubusercontent.com/fluent/fluent-bit/master/install.sh | sh > /dev/null

# 2. Configure the logging pipeline
# Overwrites the main config file with a clean, optimized pipeline
echo -e "${GREEN}[2/3]${NC} Deploying optimized configuration pipeline..."
cat <<EOF > /etc/fluent-bit/fluent-bit.conf
[SERVICE]
    Flush        1
    Log_Level    info
    Daemon       off
    Parsers_File parsers.conf
    HTTP_Server  On
    HTTP_Listen  0.0.0.0
    HTTP_Port    2020

# -------------------------------------------------------------------
# INPUTS
# -------------------------------------------------------------------
[INPUT]
    Name              tail
    Path              /var/log/auth.log
    Tag               system.auth
    Parser            syslog
    Read_From_Head    On

[INPUT]
    Name              tail
    Path              /var/ossec/logs/alerts/alerts.json
    Tag               wazuh.alerts
    Parser            json
    Read_From_Head    On

# -------------------------------------------------------------------
# OUTPUTS
# -------------------------------------------------------------------

# 1. Forward to Wazuh Manager (via Syslog TCP)
[OUTPUT]
    Name              syslog
    Match             *
    Host              192.168.1.19
    Port              514
    Mode              tcp
    Syslog_Format     rfc3164

# 2. Forward to Grafana Loki
[OUTPUT]
    Name              loki
    Match             wazuh.alerts
    Host              127.0.0.1
    Port              3100
    Labels            job=wazuh_alerts, host=wazuh_manager
    Line_Format       json

[OUTPUT]
    Name              loki
    Match             system.auth
    Host              127.0.0.1
    Port              3100
    Labels            job=system_auth, host=wazuh_manager
    Line_Format       json
EOF

# 3. Manage the systemd service
# Refresh systemd, enable the service to start on boot, and start it now
echo -e "${GREEN}[3/3]${NC} Initializing systemd service..."
systemctl daemon-reload
systemctl enable fluent-bit --now > /dev/null

# Verify the service status
if systemctl is-active --quiet fluent-bit; then
    echo -e "${BLUE}====================================================${NC}"
    echo -e "✅ INSTALLATION SUCCESSFUL!"
    echo -e "Service Status: ${GREEN}ACTIVE & RUNNING${NC}"
    echo -e "${BLUE}====================================================${NC}"
else
    echo -e "${RED}⚠️ Warning: Service failed to start. Run 'sudo systemctl status fluent-bit' to debug.${NC}"
fi
