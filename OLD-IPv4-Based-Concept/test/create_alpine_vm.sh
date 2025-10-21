#!/bin/bash
set -e

VM_NAME="alpine-test-client"
RAM_MB="512" # Alpine is very lightweight
VCPUS="1"
BRIDGE_IF="br0"
DISK_IMAGE="/var/lib/libvirt/images/alpine-guest.qcow2"

echo "▶️  Creating Alpine test client VM: $VM_NAME..."

sudo virt-install \
  --name "$VM_NAME" \
  --ram "$RAM_MB" \
  --vcpus "$VCPUS" \
  --disk path="$DISK_IMAGE",format=qcow2 \
  --import \
  --os-variant alpinelinux3.19 \
  --network bridge="$BRIDGE_IF",model=virtio \
  --graphics none \
  --noautoconsole

echo "✅ VM '$VM_NAME' created."
echo "   Use 'sudo virsh console $VM_NAME' to log in."
echo "   Login is 'root' with NO password."
