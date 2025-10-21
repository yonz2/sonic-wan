#!/bin/bash
#
# ==============================================================================
# Dynamic Linux Policy-Based Router Configuration Script
# (Managed by Supervisor)
# ==============================================================================
# This script reads its configuration from environment variables, injects
# runtime configs, and sets up all necessary interfaces, routing rules,
# and firewall policies for the router.
# ==============================================================================

# Exit immediately if a command exits with a non-zero status.
set -e

# --- [0] ENABLE DEBUGGING ---
# 'set -x' prints each command to stderr before it is executed.
# This is useful for debugging. You can comment this out for production.
echo "✅ [Router Script] Enabling detailed command tracing (set -x)..."
set -x


# --- [A] INJECT DYNAMIC CONFIGS ---
echo "--- STEP A: Injecting dynamic configurations ---"
if [ -d "/configs-to-inject/zerotier" ]; then
    echo "✅ [Router Script] Found ZeroTier configs to inject. Copying..."
    # The path inside the container is generic, without the node name
    cp -a /configs-to-inject/zerotier/. /var/lib/zerotier-one/
fi
if [ -d "/configs-to-inject/wireguard" ]; then
    echo "✅ [Router Script] Found WireGuard configs to inject. Copying..."
    # The path inside the container is generic, without the node name
    cp -a /configs-to-inject/wireguard/. /etc/wireguard/
    chmod 600 /etc/wireguard/*.conf
fi

# --- [1] VALIDATE ENVIRONMENT ---
echo "--- STEP 1: Validating environment variables ---"
if [ -z "$ZT_NETWORKID" ] || [ -z "$ZT_VLAN_SUBNET" ] || [ -z "$SWA_VLAN_SUBNET" ] || [ -z "$IOT_VLAN_SUBNET" ] || [ -z "$IOT_VLAN_IP" ]; then
  echo "❌ [Router Script] Error: One or more required network environment variables are not set."
  exit 1
fi
echo "✅ [Router Script] All required environment variables are present."


# --- [2] JOIN ZEROTIER NETWORK ---
echo "--- STEP 2: Joining ZeroTier Network ---"
sleep 2 # A short delay to ensure the zerotier-one service is ready
echo "✅ [Router Script] Joining ZeroTier Network: ${ZT_NETWORKID}"
zerotier-cli join ${ZT_NETWORKID}
sleep 5 # A short delay to ensure the zerotier-one service is ready

# --- [3] APPLY ROUTING LOGIC ---
echo "--- STEP 3: Applying main routing logic ---"
# Read the LAN interface from an environment variable, defaulting to 'eth1'
LAN_IF="${LAN_IF:-eth1}"
SWA_IF="wg0"
ZT_VLAN_ID="10"
SWA_VLAN_ID="1001"
IOT_VLAN_ID="30"

echo "--- STEP 3.1: Preparing system for routing (Cleanup) ---"
# The '|| true' swallows errors if the rules/tables don't exist on the first run.
ip rule del from all to ${ZT_NETWORK_SUBNET} 2>/dev/null || true
ip rule del from ${ZT_VLAN_SUBNET} 2>/dev/null || true
ip rule del from ${SWA_VLAN_SUBNET} 2>/dev/null || true
ip rule del from ${IOT_VLAN_SUBNET} 2>/dev/null || true
ip route flush table zerotier_wan || true
ip route flush table swa_wan || true

echo "--- STEP 3.2: Configuring VLAN interfaces ---"
# ZeroTier VLAN
ip link add link ${LAN_IF} name ${LAN_IF}.${ZT_VLAN_ID} type vlan id ${ZT_VLAN_ID}
ip addr add ${ZT_VLAN_IP} dev ${LAN_IF}.${ZT_VLAN_ID}
ip link set dev ${LAN_IF}.${ZT_VLAN_ID} up
# SWA VLAN
ip link add link ${LAN_IF} name ${LAN_IF}.${SWA_VLAN_ID} type vlan id ${SWA_VLAN_ID}
ip addr add ${SWA_VLAN_IP} dev ${LAN_IF}.${SWA_VLAN_ID}
ip link set dev ${LAN_IF}.${SWA_VLAN_ID} up
# IoT VLAN
ip link add link ${LAN_IF} name ${LAN_IF}.${IOT_VLAN_ID} type vlan id ${IOT_VLAN_ID}
ip addr add ${IOT_VLAN_IP} dev ${LAN_IF}.${IOT_VLAN_ID}
ip link set dev ${LAN_IF}.${IOT_VLAN_ID} up

echo "--- STEP 3.3: Manually bringing up WireGuard interface ${SWA_IF} ---"

# --- Dynamically read SWA_IP from the config file ---
SWA_IP=$(awk -F'=' '/Address/ {gsub(/ /, "", $2); print $2}' "/etc/wireguard/${SWA_IF}.conf")

# Validate that we found an IP address
if [ -z "$SWA_IP" ]; then
    echo "❌ [Router Script] Error: Could not find 'Address =' in /etc/wireguard/${SWA_IF}.conf"
    exit 1
fi
echo "✅ [Router Script] Discovered WireGuard IP from config: ${SWA_IP}"
# --- End of dynamic IP section ---

SWA_MTU="1420"
SWA_FWMARK="51820"

ip link add dev ${SWA_IF} type wireguard
# Filter out Address/DNS lines and pipe the result to wg setconf
grep -vE '^(Address|DNS) =' /etc/wireguard/${SWA_IF}.conf | wg setconf ${SWA_IF} /dev/stdin
ip address add ${SWA_IP} dev ${SWA_IF}
ip link set mtu ${SWA_MTU} up dev ${SWA_IF}
resolvconf -a ${SWA_IF} < /etc/wireguard/${SWA_IF}.conf
wg set ${SWA_IF} fwmark ${SWA_FWMARK}
ip -4 route add 0.0.0.0/0 dev ${SWA_IF} table ${SWA_FWMARK}
ip -4 rule add not fwmark ${SWA_FWMARK} table ${SWA_FWMARK}
ip -4 rule add table main suppress_prefixlength 0

echo "--- STEP 3.3b: Discovering ZeroTier interface name ---"
ZT_IF=$(zerotier-cli listnetworks -j | jq -r ".[] | select(.id==\"${ZT_NETWORKID}\") | .portDeviceName")
if [ -z "$ZT_IF" ]; then
    echo "❌ [Router Script] Error: Could not find ZeroTier interface for network ${ZT_NETWORKID}."
    exit 1
fi
echo "✅ [Router Script] Discovered ZeroTier interface: ${ZT_IF}"

echo "--- STEP 3.4: Populating routing tables and policy rules ---"
ip route add default dev ${ZT_IF} table zerotier_wan
ip route add default dev ${SWA_IF} table swa_wan
# Main routing rules
ip rule add to ${ZT_NETWORK_SUBNET} table zerotier_wan priority 900
ip rule add from ${ZT_VLAN_SUBNET} table zerotier_wan priority 1000
ip rule add from ${SWA_VLAN_SUBNET} table swa_wan priority 1001
# Two-rule logic for the IoT VLAN
ip rule add from ${IOT_VLAN_SUBNET} to ${ZT_NETWORK_SUBNET} table zerotier_wan priority 1002
ip rule add from ${IOT_VLAN_SUBNET} table swa_wan priority 1003


# --- [4] CONFIGURE FIREWALL FORWARDING RULES (To-Do) ---
echo "--- STEP 4: Configuring firewall FORWARD rules ---"
# This is where you will add the specific iptables rules to control traffic
# between your VLANs and tunnels, as outlined in the README.md To-Do list.
#
# Example: Set a default-deny policy for all forwarded traffic.
# iptables -P FORWARD DROP
#
# Example: Allow established connections to return.
# iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
#
# Example: Allow traffic from the SWA VLAN (1001) to go out the SWA tunnel.
# iptables -A FORWARD -i ${LAN_IF}.${SWA_VLAN_ID} -o ${SWA_IF} -j ACCEPT
#
# Example: Allow traffic from the IoT VLAN (30) to go out the SWA tunnel.
# iptables -A FORWARD -i ${LAN_IF}.${IOT_VLAN_ID} -o ${SWA_IF} -j ACCEPT
#
# Example: Allow traffic between the IoT VLAN and the ZeroTier network.
# iptables -A FORWARD -i ${LAN_IF}.${IOT_VLAN_ID} -o ${ZT_IF} -j ACCEPT
# iptables -A FORWARD -i ${ZT_IF} -o ${LAN_IF}.${IOT_VLAN_ID} -j ACCEPT
#


# --- [5] CONFIGURE FIREWALL NAT RULES ---
echo "--- STEP 5: Configuring firewall NAT rules ---"
iptables -t nat -F POSTROUTING
# Apply Source NAT (Masquerade) for traffic leaving the tunnel interfaces.
iptables -t nat -A POSTROUTING -o ${ZT_IF} -j MASQUERADE
iptables -t nat -A POSTROUTING -o ${SWA_IF} -j MASQUERADE


# --- [6] FINALIZATION ---
echo "--- STEP 6: Disabling command tracing and completing setup ---"
# Turn off detailed command tracing
set +x

echo "✅ [Router Script] Policy router configuration applied successfully."