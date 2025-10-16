#!/bin/bash
# ------------------------------------------------------------------------------
# pbr-setup.sh
# Configures policy-based routing for SONiC Secure WAN
# ------------------------------------------------------------------------------
# Purpose:
#   - Route internal (site-to-site) traffic via ZeroTier tunnel (zt0)
#   - Route Internet traffic via WireGuard tunnel (wg0)
#   - Ensure coexistence with SONiC routing (no config_db.json edits)
# ------------------------------------------------------------------------------

set -e

echo "=== Setting up Policy-Based Routing (PBR) for SONiC WAN ==="

# Define routing tables
ZT_TABLE=100
WG_TABLE=200

# Clean up old rules and tables if re-running
ip rule flush
ip route flush table $ZT_TABLE
ip route flush table $WG_TABLE

# ------------------------------------------------------------------------------
# Define gateways and interfaces
# ------------------------------------------------------------------------------
ZT_IF="zt0"
WG_IF="wg0"

# Read gateways dynamically (optional fallback to static)
ZT_GW=$(ip -4 addr show $ZT_IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)
WG_GW=$(ip -4 addr show $WG_IF | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)

echo "ZT gateway: $ZT_GW"
echo "WG gateway: $WG_GW"

# ------------------------------------------------------------------------------
# Create table entries
# ------------------------------------------------------------------------------

# ZeroTier overlay (site-to-site)
ip route add default dev $ZT_IF table $ZT_TABLE

# WireGuard secure web access
ip route add default dev $WG_IF table $WG_TABLE

# ------------------------------------------------------------------------------
# Define source-based routing rules
# ------------------------------------------------------------------------------
# Example VLAN definitions:
#   VLAN10 - Corp / User traffic → Internet (WireGuard)
#   VLAN30 - IoT sensors → Overlay (ZeroTier)

# Route VLAN 10 via WireGuard
ip rule add from 192.168.10.0/24 lookup $WG_TABLE pref 100

# Route VLAN 30 via ZeroTier
ip rule add from 192.168.30.0/24 lookup $ZT_TABLE pref 110

# ------------------------------------------------------------------------------
# Enable NAT on both tunnels
# ------------------------------------------------------------------------------
iptables -t nat -A POSTROUTING -o $WG_IF -j MASQUERADE
iptables -t nat -A POSTROUTING -o $ZT_IF -j MASQUERADE

# ------------------------------------------------------------------------------
# Default forwarding & verification
# ------------------------------------------------------------------------------
sysctl -w net.ipv4.ip_forward=1

echo "✅ Policy-based routing configured successfully."
ip rule show
