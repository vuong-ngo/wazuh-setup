#!/bin/bash

# ==============================================================================
# SCRIPT: install_agent_fluent_bit.sh
# DESCRIPTION: Automates the installation of Fluent Bit on Ubuntu systems.
# ==============================================================================

set -e

echo "===================================================="
echo ">>> Starting Fluent Bit installation process..."
echo "===================================================="

# 1. Update system packages and install required prerequisite tools
echo ">>> [1/4] Updating system packages and installing prerequisites..."
sudo apt-get update
sudo apt-get install -y curl gnupg2 apt-transport-https ca-certificates lsb-release

# 2. Add the official Fluent Bit GPG key for package verification
echo ">>> [2/4] Adding official Fluent Bit GPG key..."
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://packages.fluentbit.io/fluentbit.gpg | sudo gpg --dearmor --yes -o /usr/share/keyrings/fluentbit-keyring.gpg

# 3. Add the Fluent Bit repository to the APT sources list securely
echo ">>> [3/4] Configuring APT Repository..."

# Reliable fallback to detect distribution codename if lsb_release fails
if [ -f /etc/os-release ]; then
    . /etc/os-release
    CODENAME=$VERSION_CODENAME
else
    CODENAME=$(lsb_release -cs)
fi

# Ensure CODENAME is not empty before proceeding
if [ -z "$CODENAME" ]; then
    echo "ERROR: Failed to detect Ubuntu codename. Exiting."
    exit 1
fi

echo ">>> Detected Ubuntu version codename: $CODENAME"
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$CODENAME $CODENAME main" | sudo tee /etc/apt/sources.list.d/fluent-bit.list

# 4. Update APT cache and install the fluent-bit package
echo ">>> [4/4] Installing Fluent Bit package..."
sudo apt-get update
sudo apt-get install -y fluent-bit

# 5. Enable and start the background service via systemd
echo ">>> Enabling systemd service..."
sudo systemctl daemon-reload
sudo systemctl enable fluent-bit
sudo systemctl start fluent-bit

echo "===================================================="
echo ">>> Installation SUCCESSFUL! Check the service status with:"
echo "    sudo systemctl status fluent-bit"
echo "===================================================="
