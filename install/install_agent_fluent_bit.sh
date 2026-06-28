#!/bin/bash
# ==============================================================================
# SCRIPT: setup_agent.sh
# DESCRIPTION: Automates the installation of Fluent-bit on the host system.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

echo "🚀 [1/3] Adding Fluent-bit GPG key and repository..."

# Add official GPG key for package verification
curl -fsSL https://packages.fluentbit.io/fluentbit.key | gpg --dearmor -o /usr/share/keyrings/fluentbit-keyring.gpg

# Detect OS codename (e.g., jammy, focal) and add to repository list
OS_CODENAME=$(lsb_release -cs)
echo "deb [signed-by=/usr/share/keyrings/fluentbit-keyring.gpg] https://packages.fluentbit.io/ubuntu/$OS_CODENAME $OS_CODENAME main" | tee /etc/apt/sources.list.d/fluentbit.list

echo "📦 [2/3] Updating package index and installing Fluent-bit..."
apt-get update -y
apt-get install -y fluent-bit

echo "🔄 [3/3] Enabling and starting Fluent-bit service..."
systemctl daemon-reload
systemctl enable fluent-bit
systemctl restart fluent-bit

echo "========================================================================"
echo "✅ INSTALLATION SUCCESSFUL!"
echo "Fluent-bit service is now active and running."
echo "========================================================================"
