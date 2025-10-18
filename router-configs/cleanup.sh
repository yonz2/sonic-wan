#!/bin/bash
# =========================================================
# cleanup.sh
# Resets the VLAN and SVI configuration on the SONiC VM.
# =========================================================
set -e

echo ">>> Resetting VLAN and SVI configuration..."

# --- 1. Remove SVI IP Addresses ---
echo "--> Removing IP from Vlan10 and Vlan30..."
sudo config interface ip remove Vlan10 $(show ip interface Vlan10 | awk '/^Vlan10/ {print $2}') || echo "Vlan10 has no IP."
sudo config interface ip remove Vlan30 $(show ip interface Vlan30 | awk '/^Vlan30/ {print $2}') || echo "Vlan30 has no IP."


# --- 2. Remove VLAN Members ---
echo "--> Removing members from VLANs..."
sudo config vlan member del 10 Ethernet0 || echo "Ethernet0 not in VLAN 10."
sudo config vlan member del 30 Ethernet0 || echo "Ethernet0 not in VLAN 30."
sudo config vlan member del 1001 Ethernet0 || echo "Ethernet0 not in VLAN 1001."

# --- 3. Delete the VLANs ---
echo "--> Deleting VLANs..."
sudo config vlan del 10 || echo "VLAN 10 does not exist."
sudo config vlan del 30 || echo "VLAN 30 does not exist."
sudo config vlan del 1001 || echo "VLAN 1001 does not exist."

# --- 4. Save the clean configuration ---
echo "--> Saving configuration..."
sudo config save -y

echo "✅ Cleanup complete."