#!/bin/bash
# =========================================================
# create_test_client_vm.sh
# Creates and starts a lightweight Ubuntu test client VM.
# =========================================================
set -e

VM_NAME="ubuntu-test-client"
RAM_MB="1024" # 1GB is plenty for a client
VCPUS="1"
BRIDGE_IF="br0"
DISK_IMAGE="/var/lib/libvirt/images/ubuntu-test-client.qcow2"

echo "▶️  Creating test client VM: $VM_NAME..."

sudo virt-install \
  --name "$VM_NAME" \
  --ram "$RAM_MB" \
  --vcpus "$VCPUS" \
  --disk path="$DISK_IMAGE",format=qcow2 \
  --import \
  --os-variant ubuntunoble \
  --network bridge="$BRIDGE_IF",model=virtio \
  --graphics none \
  --noautoconsole

echo "✅ VM '$VM_NAME' created. It may take a minute to boot and get an IP."
echo "   Use 'sudo virsh console $VM_NAME' to log in (user: ubuntu, no password)."
