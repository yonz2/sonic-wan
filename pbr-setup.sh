#!/bin/bash
# ------------------------------------------------------------------------------
# pbr-setup.sh
# Policy-Based Routing between SONiC VLANs and Tunnel Interfaces
# ------------------------------------------------------------------------------

set -e

echo "=== Applying SONiC PBR Rules ==="

# Clean up any previous tables
sudo ip rule flush
sudo ip route flush table 100 || true
sudo ip route flush table 200 || true

# Create policy routing tables
echo "100 wg_table" | sudo tee -a /etc/iproute2/rt_tables
echo "200 zt_table" | sudo tee -a /etc/iproute2/rt_tables

# Routes for each table
sudo ip route add default dev wg0 table wg_table
sudo ip route add default dev zt0 table zt_table

# Apply policy rules: VLAN 10 → WireGuard, VLAN 20 → ZeroTier
sudo ip rule add iif Vlan10 table wg_table priority 1000
sudo ip rule add iif Vlan20 table zt_table priority 1001

# Optional: enable NAT for VLAN egress through tunnels
sudo iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -o zt0 -j MASQUERADE

echo "✅ PBR setup complete."
echo "Check rules with: ip rule show && ip route show table wg_table"

