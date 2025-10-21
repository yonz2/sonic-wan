#!/bin/bash
# =========================================================
# setup_vlans_final.sh
#
# Purpose:
#  - Reliably prepares a SONiC VM for L2/L3 VLAN testing.
#  - Correctly handles interfaces with multiple IP addresses.
# =========================================================

set -e

# --- List of physical interfaces to convert from L3 to L2 ---
INTERFACES_TO_CLEAN="Ethernet0 Ethernet4 Ethernet8 Ethernet12 Ethernet16 Ethernet20 Ethernet24 Ethernet28"

echo ">>> SONiC VLAN and SVI configuration starting..."

# --- 1. Remove L3 configuration from physical ports ---
echo "--> Removing IP configurations from physical interfaces..."
for IFACE in $INTERFACES_TO_CLEAN; do
    # Find all IPs on the interface and loop through them
    show ip interfaces | grep "$IFACE" | awk '{print $2}' | while read -r CURRENT_IP; do
        if [ -n "$CURRENT_IP" ]; then
            echo "    - Removing IP $CURRENT_IP from $IFACE"
            sudo config interface ip remove "$IFACE" "$CURRENT_IP"
        fi
    done || echo "    - $IFACE has no IP. Skipping."
done

# --- 2. Create the necessary VLANs ---
echo "--> Creating VLANs 10, 30, and 1001..."
sudo config vlan add 10 || echo "    - VLAN 10 already exists."
sudo config vlan add 30 || echo "    - VLAN 30 already exists."
sudo config vlan add 1001 || echo "    - VLAN 1001 already exists."

# --- 3. Configure the trunk port ---
echo "--> Configuring Ethernet0 as a trunk port for VLANs 10, 30, 1001..."
sudo config vlan member add 10 Ethernet0 || echo "    - Ethernet0 is already a member of VLAN 10."
sudo config vlan member add 30 Ethernet0 || echo "    - Ethernet0 is already a member of VLAN 30."
sudo config vlan member add 1001 Ethernet0 || echo "    - Ethernet0 is already a member of VLAN 1001."

# --- 4. Create the SVI gateway interfaces ---
echo "--> Creating SVI gateways for VLAN 10 and 30..."
sudo config interface ip add Vlan10 192.168.10.1/24 || echo "    - Vlan10 already has an IP."
sudo config interface ip add Vlan30 192.168.30.1/24 || echo "    - Vlan30 already has an IP."

# --- 5. Bring the VLAN interfaces up ---
echo "--> Bringing VLAN interfaces up..."
# ADDED QUOTES to fix the "invalid interface" error
sudo config interface startup "Vlan10"
sudo config interface startup "Vlan30"

# --- 6. Save the configuration persistently ---
echo "--> Saving configuration..."
sudo config save -y

echo ""
echo "✅ SONiC configuration applied successfully."
echo "   Run 'show vlan brief' and 'show ip interface' to verify."