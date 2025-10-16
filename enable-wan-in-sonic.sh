#!/bin/bash
# ==============================================================================
# enable-wan-in-sonic.sh
# ------------------------------------------------------------------------------
# Deploys WireGuard and ZeroTier containers inside SONiC
# and prepares the environment for Policy-Based Routing (PBR).
#
# Author: Yonz / Net-Innovate Solutions GmbH
# License: The Unlicense
# Version: 2025-10-16
# ------------------------------------------------------------------------------
# Layout:
#   /home/admin/sonic-wan/
#     ├── .secrets/
#     │    ├── wireguard/
#     │    │     └── wg0.conf
#     │    └── zerotier/
#     │          ├── identity.public
#     │          └── identity.secret
#     ├── wan-containers.sh
#     ├── pbr-setup.sh      ← manually maintained
#     └── enable-wan-in-sonic.sh
# ==============================================================================

set -e

BASE_DIR="/home/admin/sonic-wan"
SECRETS_DIR="$BASE_DIR/.secrets"
WIREGUARD_DIR="/etc/wireguard"
ZEROTIER_DIR="/var/lib/zerotier-one"

echo "=== [SONiC WAN ENABLEMENT] Starting setup from $BASE_DIR ==="

# ------------------------------------------------------------------------------
# 1. Prepare directories
# ------------------------------------------------------------------------------
sudo mkdir -p "$WIREGUARD_DIR" "$ZEROTIER_DIR" "$BASE_DIR/logs"
sudo chmod 700 "$WIREGUARD_DIR" "$ZEROTIER_DIR"

# ------------------------------------------------------------------------------
# 2. Inject configs and identities
# ------------------------------------------------------------------------------
if [ ! -f "$WIREGUARD_DIR/wg0.conf" ]; then
  sudo cp "$SECRETS_DIR/wireguard/"* "$WIREGUARD_DIR/"
  echo "✅  WireGuard configuration copied from $SECRETS_DIR/wireguard/"
else
  echo "ℹ️  WireGuard configuration already present, skipping copy."
fi

if [ ! -f "$ZEROTIER_DIR/identity.secret" ]; then
  sudo cp "$SECRETS_DIR/zerotier/"* "$ZEROTIER_DIR/"
  echo "✅  ZeroTier identities copied from $SECRETS_DIR/zerotier/"
else
  echo "ℹ️  ZeroTier identity already present, skipping copy."
fi

# ------------------------------------------------------------------------------
# 3. Launch WAN containers
# ------------------------------------------------------------------------------
echo "🚀 Starting WAN containers (WireGuard + ZeroTier)..."
bash "$BASE_DIR/wan-containers.sh" both

echo "✅ Containers launched. Verify with: docker ps"
echo "🔹 Join ZeroTier network using:"
echo "   docker exec -it zerotier zerotier-cli join <network-id>"
echo

# ------------------------------------------------------------------------------
# 4. Optional: Add alias for manual PBR runs
# ------------------------------------------------------------------------------
if [ -f "$BASE_DIR/pbr-setup.sh" ]; then
  if ! grep -q "pbr-setup.sh" /home/admin/.bashrc; then
    echo "alias pbr-setup='sudo bash $BASE_DIR/pbr-setup.sh'" >> /home/admin/.bashrc
    echo "✅  Added alias: pbr-setup (rerun policy routing)"
  else
    echo "ℹ️  Alias pbr-setup already present in .bashrc"
  fi
else
  echo "⚠️  No pbr-setup.sh found in $BASE_DIR — skipping alias setup"
fi

# ------------------------------------------------------------------------------
# 5. Done
# ------------------------------------------------------------------------------
echo
echo "✅ SONiC WAN enablement complete!"
echo "   - Base directory: $BASE_DIR"
echo "   - Configs copied from: $SECRETS_DIR"
echo "   - Containers managed by: $BASE_DIR/wan-containers.sh"
echo "   - PBR script (manual): $BASE_DIR/pbr-setup.sh"
echo
echo "To reapply routing rules manually (if pbr-setup.sh exists): pbr-setup"
echo
echo "=== [DONE] SONiC Secure WAN environment ready ==="
