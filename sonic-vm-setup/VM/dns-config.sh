#!/bin/bash

# ==============================================================================
# configure_sonic_dns.sh
#
# This script configures DNS name resolution inside a SONiC VM to enable
# outbound internet access for tasks like pulling Docker containers or
# updating packages.
#
# It works by prepending specified nameservers to the system's DNS
# configuration using the 'resolvconf' utility.
#
# IMPORTANT: This script is intended to be run INSIDE the SONiC VM, not on
#            the host machine.
#
# Usage:
#   1. Copy this script to your SONiC VM (e.g., using scp or copy-paste).
#   2. Make it executable: chmod +x configure_sonic_dns.sh
#   3. Run with sudo:     sudo ./configure_sonic_dns.sh
# ==============================================================================

# --- DNS Configuration ---
# You can change the DNS servers by editing the variables below.
# The primary server is typically your local network's DNS resolver.
# The secondary is a public DNS server for fallback.
PRIMARY_DNS="10.0.0.3"
SECONDARY_DNS="8.8.8.8"

# --- System File Paths ---
RESOLVCONF_CONFIG_FILE="/etc/resolvconf/resolv.conf.d/head"

# --- Pre-flight Checks ---

# 1. Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: This script must be run with sudo or as root."
  exit 1
fi

# 2. Check if the 'resolvconf' command is available
if ! command -v resolvconf &> /dev/null; then
    echo "❌ Error: The 'resolvconf' utility is not found."
    echo "   This script is designed for Debian-based systems that use it."
    exit 1
fi


# --- Main Logic ---

echo "▶️  Configuring DNS with servers: $PRIMARY_DNS, $SECONDARY_DNS"

# The 'head' file in this directory is prepended to the final resolv.conf.
# This ensures our custom nameservers are tried first.
# We use 'tee' to write the content with root privileges and a 'here document'
# (<<'EOF') for clean, multi-line input.
sudo tee "$RESOLVCONF_CONFIG_FILE" >/dev/null <<EOF
nameserver $PRIMARY_DNS
nameserver $SECONDARY_DNS
EOF

echo "✅ Configuration written to '$RESOLVCONF_CONFIG_FILE'."
echo "▶️  Updating the system's DNS resolver..."

# The '-u' flag tells resolvconf to update its database and regenerate
# the main /etc/resolv.conf file with our new changes.
sudo resolvconf -u

echo "✅ DNS configuration has been updated."
echo ""

# --- Verification Steps ---

echo "▶️  Verifying the new configuration..."
echo "--- Contents of /etc/resolv.conf ---"
cat /etc/resolv.conf
echo "------------------------------------"
echo ""

echo "▶️  Testing network connectivity by pinging a public host..."
# We ping a reliable host to confirm that name resolution and outbound
# connectivity are both working.
if ping -c 3 registry-1.docker.io; then
  echo "✅ DNS resolution appears to be working successfully!"
else
  echo "⚠️ Warning: Ping test failed. There may be a firewall or network issue."
fi

# ==============================================================================
# Optional Final Test
#
# The following command can be uncommented to perform a full end-to-end test
# by pulling a small container image from Docker Hub.
# ==============================================================================
# sudo docker run hello-world
