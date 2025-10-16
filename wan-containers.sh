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
#     ├── wireguard/wg0.conf
#     └── zerotier/
#          ├── identity.public
#          └── identity.secret
#
#   logs/
#     ├── wireguard.log
#     └── zerotier.log
#
#   Scripts:
#     ├── enable-wan-in-sonic.sh
#     └── wan-containers.sh
#
# ------------------------------------------------------------------------------
# NOTE ABOUT CUSTOM ZEROTIER IMAGE:
# ---------------------------------
# This script assumes a *custom* ZeroTier image called `zerotier:wan` exists locally.
# You must manually copy the image tarball to the SONiC VM and import it as follows:
#
#   scp zerotier-wan.tar admin@<sonic-vm>:/home/admin/
#   ssh admin@<sonic-vm>
#   sudo docker load -i /home/admin/zerotier-wan.tar
#
# Do NOT script this step — it’s intentionally manual to maintain image control
# during pre-bake and testing phases.
# ==============================================================================

set -e

BASE_DIR="/home/admin/sonic-wan"
SECRETS_DIR="$BASE_DIR/.secrets"
LOG_DIR="$BASE_DIR/logs"

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
    zerotier:wan >> "$LOG_DIR/zerotier.log" 2>&1

  sleep 2
  log "✅ ZeroTier container started (image: zerotier:wan, name: zerotier)."
  log "   Join network using: docker exec -it zerotier zerotier-cli join <network-id>"
}

# ------------------------------------------------------------------------------ 
# Function: start_wireguard
# ------------------------------------------------------------------------------
start_wireguard() {
  log "Starting WireGuard container (linuxserver/wireguard:latest)..."

  if sudo docker ps -a --format '{{.Names}}' | grep -q '^wireguard$'; then
    log "Existing WireGuard container found — removing..."
    sudo docker rm -f wireguard >/dev/null 2>&1 || true
  fi

  sudo docker run -d \
    --name wireguard \
    --restart=unless-stopped \
    --cap-add=NET_ADMIN \
    --cap-add=SYS_MODULE \
    --device /dev/net/tun \
    --sysctl net.ipv4.conf.all.src_valid_mark=1 \
    --sysctl net.ipv4.ip_forward=1 \
    -v /etc/wireguard:/config \
    -v "$LOG_DIR":/logs \
    linuxserver/wireguard:latest >> "$LOG_DIR/wireguard.log" 2>&1

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
