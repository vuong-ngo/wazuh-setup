#!/bin/bash

# ==============================================================================
# SCRIPT: install_agent_fluent_bit.sh
# DESCRIPTION: Automates the installation of Fluent-bit on the host system.
# ==============================================================================

set -e

echo "===================================================="
echo ">>> Starting Fluent Bit installation process..."
echo "===================================================="

# 1. Update system packages and install required prerequisite tools
echo ">>> [1/4] Updating system packages and installing curl, gnupg..."
sudo apt-get update
sudo apt-get install -y curl gnupg2 apt-transport-https ca-certificates

# 2. Add the official Fluent Bit GPG key for package verification
echo ">>> [2/4] Adding official Fluent Bit GPG key..."
sudo mkdir -p /usr/share/keyrings
curl -fsSL https://packages.fluentbit.io/fluentbit.gpg | sudo gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg

# 3. Add the Fluent Bit repository to the APT sources list
echo ">>> [3/4] Configuring APT Repository..."
# Automatically detect the distribution codename (e.g., focal, jammy, noble...)
CODENAME=$(lsb_release -cs)
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
