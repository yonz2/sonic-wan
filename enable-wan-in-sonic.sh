#!/bin/bash
# ------------------------------------------------------------------------------
# enable-wan-in-sonic.sh
# Deploys WireGuard and ZeroTier containers inside SONiC
# ------------------------------------------------------------------------------
#
# Note: This script assumes that the idenities and config files for the containers are stored in a local .secrets folder
#         ./.secrets/wireguard
#         ./.secrets/zerotier

set -e

echo "=== SONiC WAN Container Setup ==="

# Ensure directories exist
sudo mkdir -p /etc/wireguard /var/lib/zerotier-one /var/log/wireguard

# Inject (copy) configuration and identity files if missing.
if [ ! -f /etc/wireguard/wg0.conf ]; then
  sudo cp ./.secrets/wireguard/* /etc/wireguard/
  echo "✅  WireGuard config copied from .secret/wireguard - WireGuard will pull up the defined tunnel"
fi
if [ ! -f /var/lib/zerotier-one/identity.secret ]; then
  sudo cp ./.secrets/zerotier/* /var/lib/zerotier-one/
  echo "✅  Zerotier identieties copied from .secret/zerotier - Zerotier will use static identity"
fi


# Bring up the containers
echo "🚀 Starting WAN containers (WireGuard + ZeroTier)..."
./wan-containers.sh both

echo "✅ Containers launched. Verify with: docker ps"
echo "🔹 Join ZeroTier network using: docker exec -it zerotier zerotier-cli join <network-id>"

