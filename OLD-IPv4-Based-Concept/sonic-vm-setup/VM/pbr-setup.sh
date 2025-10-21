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

# --- Define Constants ---
ZT_TABLE=100
WG_TABLE=200
ZT_IF="zt0"
WG_IF="wg0"

# --- Graceful Cleanup of Old Rules and Tables ---
# This prevents errors if the script is run on a clean system where
# the tables and rules do not yet exist.
echo "▶️  Cleaning up previous PBR configuration..."
ip rule flush
ip route flush table $ZT_TABLE 2>/dev/null || true
ip route flush table $WG_TABLE 2>/dev/null || true

# --- Validate that Tunnel Interfaces are UP ---
echo "▶️  Validating network interfaces..."
if ! ip link show "$ZT_IF" up > /dev/null 2>&1; then
    echo "❌ Error: ZeroTier interface '$ZT_IF' is not up or does not exist."
    exit 1
fi
if ! ip link show "$WG_IF" up > /dev/null 2>&1; then
    echo "❌ Error: WireGuard interface '$WG_IF' is not up or does not exist."
    exit 1
fi
echo "✅ Interfaces '$ZT_IF' and '$WG_IF' are up."

# ------------------------------------------------------------------------------
# Create Routing Table Entries
# ------------------------------------------------------------------------------
echo "▶️  Configuring routing tables..."

# Route all traffic in the ZeroTier table through the zt0 interface
ip route add default dev $ZT_IF table $ZT_TABLE

# Route all traffic in the WireGuard table through the wg0 interface
ip route add default dev $WG_IF table $WG_TABLE

# ------------------------------------------------------------------------------
# Define Source-Based Routing Rules
# ------------------------------------------------------------------------------
# Example VLAN definitions:
#   VLAN10 - Corp / User traffic → Internet (WireGuard)
#   VLAN30 - IoT sensors → Overlay (ZeroTier)
echo "▶️  Adding policy routing rules..."

# Route traffic from VLAN 10's subnet to the WireGuard table
ip rule add from 192.168.10.0/24 lookup $WG_TABLE pref 100

# Route traffic from VLAN 30's subnet to the ZeroTier table
ip rule add from 192.168.30.0/24 lookup $ZT_TABLE pref 110

# ------------------------------------------------------------------------------
# Enable NAT on both Tunnels
# ------------------------------------------------------------------------------
echo "▶️  Enabling NAT (Masquerade) on tunnel interfaces..."
# Use -C to check if the rule exists before adding it, to avoid duplicates.
if ! iptables -t nat -C POSTROUTING -o $WG_IF -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -o $WG_IF -j MASQUERADE
fi
if ! iptables -t nat -C POSTROUTING -o $ZT_IF -j MASQUERADE 2>/dev/null; then
    iptables -t nat -A POSTROUTING -o $ZT_IF -j MASQUERADE
fi

# ------------------------------------------------------------------------------
# Enable IP Forwarding & Verification
# ------------------------------------------------------------------------------
echo "▶️  Enabling kernel IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

echo "✅ Policy-based routing configured successfully."
echo "--- Current IP Rules: ---"
ip rule show
echo "-------------------------"
