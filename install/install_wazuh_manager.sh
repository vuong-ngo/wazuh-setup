#!/bin/bash
# ==============================================================================
# SCRIPT TO INSTALL ONLY THE WAZUH MANAGER CORE (STANDALONE - LIGHTWEIGHT)
# Supported OS: Ubuntu / Debian
# ==============================================================================

# Stop execution immediately if any command fails
set -e

echo "🚀 [1/4] Updating system and installing prerequisites..."
apt-get update -y
apt-get install -y curl apt-transport-https unzip wget libcap2-bin software-properties-common lsb-release gnupg

echo "🔑 [2/4] Configuring official Wazuh GPG Key..."
curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | gpg --no-default-keyring --keyring gnupg-ring:/usr/share/keyrings/wazuh.gpg --import
chmod 644 /usr/share/keyrings/wazuh.gpg

echo "📦 [3/4] Adding Wazuh Repository (Version 4.x)..."
echo "deb [signed-by=/usr/share/keyrings/wazuh.gpg] https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list

echo "⚙️ [4/4] Downloading and installing Wazuh Manager core..."
apt-get update -y
apt-get install -y wazuh-manager

echo "🔄 Enabling and starting Wazuh Manager service..."
systemctl daemon-reload
systemctl enable wazuh-manager
systemctl restart wazuh-manager

echo "========================================================================"
echo "✅ INSTALLATION COMPLETE!"
echo "Wazuh Manager core has been cleanly installed and is running in the background."
echo "Current service status:"
systemctl status wazuh-manager --no-pager | grep "Active:"
echo "========================================================================"
