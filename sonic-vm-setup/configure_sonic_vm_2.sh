#!/bin/bash

# ==============================================================================
# configure_sonic_vm.sh
#
# This script performs the initial configuration of a fresh SONiC VM from the
# host machine. It handles SSH key setup, DNS configuration, Git installation,
# repository cloning, and Docker image deployment.
#
# Prerequisites:
#   1. The SONiC VM must be running and accessible by name from the host.
#   2. The local files specified in the 'Local File Paths' section must exist
#      at the correct relative paths to this script.
#
# Usage:
#   ./configure_sonic_vm.sh
#
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
VM_USER="admin"
VM_HOST="sonic"

BASE_DIR_HOST="${PWD}"

# --- Local File Paths ---
SSH_KEY_PUB="${HOME}/.ssh/id_ed25519.pub"
DNS_SCRIPT="VM/dns-config.sh"
SIDECAR_CONTAINERS_SCRIPT="VM/wan-containers.sh"
PBR_SETUP_SCRIPT="VM/pbr-setup.sh"

ZEROTIER_IMAGE_PATH="${BASE_DIR_HOST}/../containers/zerotier/zerotier.tar.gz"
WIREGUARD_IMAGE_PATH="${BASE_DIR_HOST}/../containers/wireguard/wireguard.tar.gz"
SECRETS_DIR="${BASE_DIR_HOST}/../.secrets"

# --- Remote Paths (on the VM) ---
REMOTE_HOME_DIR="/home/${VM_USER}"
REMOTE_IMAGE_DIR="${REMOTE_HOME_DIR}/container-images"
REMOTE_SECRETS_DIR="${REMOTE_HOME_DIR}/.secrets"

# --- Pre-flight Checks ---
echo "▶️  Performing pre-flight checks..."
for f in "$SSH_KEY_PUB" "$DNS_SCRIPT" "$ZEROTIER_IMAGE_PATH" "$WIREGUARD_IMAGE_PATH"; do
    if [ ! -f "$f" ]; then
        echo "❌ Error: Required local file not found: $f"
        exit 1
    fi
done
echo "✅ All required local files found."
echo ""

# === 3. Transfer Docker Container Images ===
echo "▶️  Step 5: Transferring Docker images..."
# Ensure the target directory exists on the remote machine
ssh "${VM_USER}@${VM_HOST}" "mkdir -p '$REMOTE_IMAGE_DIR'"
scp "${ZEROTIER_IMAGE_PATH}" "${WIREGUARD_IMAGE_PATH}" "${VM_USER}@${VM_HOST}:${REMOTE_IMAGE_DIR}/"
echo "✅ Docker images transferred successfully."
echo ""


# === 4. Load Docker Images and Clean Up ===
echo "▶️  Step 4: Loading images into Docker and cleaning up..."
# Define the remote commands in a 'here document' for clarity
ssh "${VM_USER}@${VM_HOST}" << END_OF_COMMANDS
  set -e
  echo "  -> Loading ZeroTier image..."
  sudo docker load < ${REMOTE_IMAGE_DIR}/${ZEROTIER_IMAGE_PATH##*/}

  echo "  -> Loading WireGuard image..."
  sudo docker load < ${REMOTE_IMAGE_DIR}/${WIREGUARD_IMAGE_PATH##*/}

  echo "  -> Removing archive files..."
  rm ${REMOTE_IMAGE_DIR}/*.tar.gz
END_OF_COMMANDS
echo "✅ Docker images loaded and archives removed."
echo ""


# === 5a. Spin up the sidecar containers running Zerotier and Wireguard ===
echo "▶️  Step 5a: Starting Sidecar Containers - Zerotier and WireGuard inside the VM..."
# Ensure the target directory exists on the remote machine
ssh "${VM_USER}@${VM_HOST}" "mkdir -p '${REMOTE_SECRETS_DIR}'"
scp -r "${SECRETS_DIR}"/* "${VM_USER}@${VM_HOST}:${REMOTE_SECRETS_DIR}"
echo "✅ Sidecar Container config and identity files copied."
echo ""

# === 5b. Copy the wan-container.sh and pbr-setup script to the VM and run the wan-container.sh script
echo "▶️  Step 5b: Copy ${SIDECAR_CONTAINERS_SCRIPT} and ${PBR_SETUP_SCRIPT} to VM"
scp "${SIDECAR_CONTAINERS_SCRIPT}" "${PBR_SETUP_SCRIPT}" "${VM_USER}@${VM_HOST}:${REMOTE_HOME_DIR}"

# Note: The initial parameter is used to spin up both containers and run the initial pbr-setup script
echo "▶️  Step 5c: Run ${REMOTE_HOME_DIR}/${SIDECAR_CONTAINERS_SCRIPT##*/} initial on VM"
ssh "${VM_USER}@${VM_HOST}" "sudo ${REMOTE_HOME_DIR}/${SIDECAR_CONTAINERS_SCRIPT##*/} initial"
echo "✅ Sidecar Containers started."
echo ""


echo "🎉 All configuration tasks completed successfully!"
