#!/bin/bash
# ==============================================================================
# wan-containers.sh
# ------------------------------------------------------------------------------
# Starts WireGuard and/or ZeroTier containers inside SONiC using plain Docker CLI.
# Designed for minimal dependencies and full compatibility with the SONiC VM
# environment (no docker-compose, no systemd modifications).
#
# Author: Yonz / Net-Innovate Solutions GmbH
# Company: Net-Innovate Solutions GmbH
# License: The Unlicense
# Version: 2025-10-16
# ------------------------------------------------------------------------------
# Directory layout (relative to /home/admin/sonic-wan):
#
#   .secrets/
#     ├── wireguard
#          ├── /wg0.conf
#     └── zerotier/
#          ├── identity.public
#          └── identity.secret
#          └── devicemap
#          └── local.conf
#   logs/
#     ├── wireguard.log
#     └── zerotier.log
#
#   Scripts:
#     ├── enable-wan-in-sonic.sh
#     └── wan-containers.sh
#
# ------------------------------------------------------------------------------
# NOTE ABOUT CUSTOM ZEROTIER AND WIREGUARD IMAGE:
# ---------------------------------
# This script assumesthe wireguard and ZeroTier images exists locally.
# The should have been copied and loaded by the configure_sonic_vm script
# ==============================================================================

set -e

BASE_DIR="$PWD"
SECRETS_DIR="$BASE_DIR/.secrets"
LOG_DIR="$BASE_DIR/logs"
WIREGUARD_DIR="/etc/wireguard"
ZEROTIER_DIR="/var/lib/zerotier-one"

mkdir -p "$LOG_DIR"

# ------------------------------------------------------------------------------ 
# Helper for readable logging
# ------------------------------------------------------------------------------
log() { echo -e "\033[1;36m[WAN]\033[0m $*"; }

# ------------------------------------------------------------------------------ 
# Function: start_zerotier
# ------------------------------------------------------------------------------
start_zerotier() {
  log "Starting ZeroTier container (custom image: zerotier:wan)..."

  if [ ! -f "$ZEROTIER_DIR/identity.secret" ]; then
    sudo mkdir -p ${ZEROTIER_DIR}
    sudo cp "$SECRETS_DIR/zerotier/"* "$ZEROTIER_DIR/"
    echo "✅  ZeroTier identities copied from $SECRETS_DIR/zerotier/"
  else
    echo "ℹ️  ZeroTier identity already present, skipping copy."
  fi

  # Stop and remove old instance if exists
  if sudo docker ps -a --format '{{.Names}}' | grep -q '^zerotier$'; then
    log "Existing ZeroTier container found — removing..."
    sudo docker rm -f zerotier >/dev/null 2>&1 || true
  fi

  sudo docker run -d \
    --name zerotier \
    --restart=unless-stopped \
    --net=host \
    --cap-add=NET_ADMIN \
    --device /dev/net/tun \
    -v /var/lib/zerotier-one:/var/lib/zerotier-one \
    -v "$LOG_DIR":/logs \
    zerotier:wan

  sleep 2
  ZT_DEVICEMAP=`cat ${SECRETS_DIR}/zerotier/devicemap`
  ZT_NETWORKID={$ZT_DEVICEMAP%=*}
  docker exec -it zerotier zerotier-cli join ${ZT_NETWORKID}
  sleep 1
  docker exec -it zerotier zerotier-cli info
  docker exec -it zerotier zerotier-cli peers
  log "✅ ZeroTier container started (image: zerotier:wan, name: zerotier)."
  log "   Join network using: "
}

# ------------------------------------------------------------------------------ 
# Function: start_wireguard
# ------------------------------------------------------------------------------
start_wireguard() {
  log "Starting WireGuard container (linuxserver/wireguard:latest)..."

  if [ ! -f "${WIREGUARD_DIR}/wg0.conf" ]; then
    sudo mkdir -p ${WIREGUARD_DIR}
    sudo cp "${SECRETS_DIR}/wireguard/"* "${WIREGUARD_DIR}/"
    sudo chmod 600 "${WIREGUARD_DIR}/*.conf"
    echo "✅  WireGuard configuration copied from ${SECRETS_DIR}/wireguard/"
  else
    echo "ℹ️  WireGuard configuration already present, skipping copy."
  fi

  if sudo docker ps -a --format '{{.Names}}' | grep -q '^wireguard$'; then
    log "Existing WireGuard container found — removing..."
    sudo docker rm -f wireguard >/dev/null 2>&1 || true
  fi

  sudo docker run -d \
    --name wireguard \
    --restart=unless-stopped \
    --net=host \
    --cap-add=NET_ADMIN \
    --device /dev/net/tun \
    -v /etc/wireguard:/config \
    -v "$LOG_DIR":/logs \
    linuxserver/wireguard:latest

  sleep 2
  log "✅ WireGuard container started (name: wireguard)."
  log "   Check logs with: docker logs wireguard"
}

# ------------------------------------------------------------------------------ 
# Function: stop_all
# ------------------------------------------------------------------------------
stop_all() {
  log "Stopping and removing WAN containers..."
  sudo docker rm -f wireguard zerotier >/dev/null 2>&1 || true
  log "✅ All WAN containers stopped and removed."
}

# ------------------------------------------------------------------------------
# Function: Run pbr-setup.sh and add alias for manual PBR runs
# ------------------------------------------------------------------------------
pbr_initial_setup() {
  log "Running Policy based routing setup script..."
  if [ -f "$BASE_DIR/pbr-setup.sh" ]; then
    "$BASE_DIR/pbr-setup.sh"
    if ! grep -q "pbr-setup.sh" /home/admin/.bashrc; then
      echo "alias pbr-setup='sudo bash $BASE_DIR/pbr-setup.sh'" >> /home/admin/.bashrc
      echo "✅  Added alias: pbr-setup (rerun policy routing)"
    else
      echo "ℹ️  Alias pbr-setup already present in .bashrc"
    fi
  else
    echo "⚠️  No pbr-setup.sh found in $BASE_DIR — skipping alias setup"
  fi

}


# ------------------------------------------------------------------------------ 
# Main
# ------------------------------------------------------------------------------
case "$1" in
  zerotier)
    start_zerotier
    ;;
  wireguard)
    start_wireguard
    ;;
  both)
    start_wireguard
    start_zerotier
    ;;
  initial)
    start_wireguard
    start_zerotier
    pbr_initial_setup
    ;;    
  stop)
    stop_all
    ;;
  *)
    echo "Usage: $0 {zerotier|wireguard|both|stop}"
    echo
    echo "Examples:"
    echo "  $0 zerotier   → Start only ZeroTier container"
    echo "  $0 wireguard  → Start only WireGuard container"
    echo "  $0 both       → Start both containers"
    echo "  $0 stop       → Stop and remove both containers"
    exit 1
    ;;
esac
