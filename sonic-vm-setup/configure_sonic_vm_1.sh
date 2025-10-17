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
CUSTOM_NETWORKING_CONF=custom-networking.conf

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

set +x

# === 1. Enable SSH Access via Public Key ===
echo "▶️  Step 1: Enabling passwordless SSH access..."

# Use grep with '-f -' to read the pattern (the key) from stdin.
# Redirect the local public key file into the ssh command's stdin.
if ssh "${VM_USER}@${VM_HOST}" "grep -Fq -f - ~/.ssh/authorized_keys" < "$SSH_KEY_PUB"; then
  echo "ℹ️  SSH key is already authorized on the VM."
else
  echo "    You may be prompted for the '${VM_USER}' password for the VM."
  ssh-copy-id -i "$SSH_KEY_PUB" "${VM_USER}@${VM_HOST}"
  echo "✅ SSH public key has been transferred."
fi
echo ""


# === 2. Transfer Network Configuration and Run DNS Configuration Script ===

echo "▶️  Step 2a: Copy ${CUSTOM_NETWORKING_CONF}..."
scp "${CUSTOM_NETWORKING_CONF}" "${VM_USER}@${VM_HOST}:${REMOTE_HOME_DIR}"
ssh "${VM_USER}@${VM_HOST}" "sudo mv ${CUSTOM_NETWORKING_CONF} /etc/sysctl.d/99-${CUSTOM_NETWORKING_CONF}"
echo "✅ ${CUSTOM_NETWORKING_CONF} copied to /etc/sysctl.d/"
echo ""

echo "▶️  Step 2b: Configuring DNS on the VM..."
scp "$DNS_SCRIPT" "${VM_USER}@${VM_HOST}:${REMOTE_HOME_DIR}"
ssh "${VM_USER}@${VM_HOST}" "sudo ${REMOTE_HOME_DIR}/${DNS_SCRIPT##*/}"
echo "✅ DNS configuration script executed and cleaned up."
echo ""

echo "▶️  The SONiC VM will now reboot!"
echo " \n\tThis is a precautionary step to make sure all network configrations are properly acrtivated "

ssh "${VM_USER}@${VM_HOST}" "sudo reboot"

echo "Reboot started. Please wait a few minuts and then run the second part ./configure_sonic_vm_2.sh"
echo "......"


