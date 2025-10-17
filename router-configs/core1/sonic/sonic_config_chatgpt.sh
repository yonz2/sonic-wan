#!/bin/bash
# =========================================================
# sonic-config.sh
# For containerlab node: core1 (SONiC)
#
# Purpose:
#  - Make Ethernet1 an 802.1q trunk to wan-node1 (carry VLANs)
#  - Create VLANs and assign member ports (L2)
#  - Create SVIs (VlanN) for routing/gateway functions
#
# Notes / rationale:
#  - wan-node1 creates VLAN subinterfaces on its LAN IF (eth1.<vlan>).
#    Therefore core1:Ethernet1 must carry those VLANs as tagged.
#  - Devices attached to core1 (Ethernet4, Ethernet7, Ethernet8) are access
#    ports (untagged) in their respective VLANs.
#  - The script only configures SVIs if you provide an IP for them (see vars).
#    This avoids accidental IP conflicts with the router if the router is meant
#    to be the gateway.
# =========================================================

set -euo pipefail

# -----------------------------
# User-editable variables
# -----------------------------
# VLAN IDs
VLAN_ZT=10      # ZeroTier VLAN (ZT)
VLAN_IOT=30     # IoT VLAN
VLAN_SWA=1001   # SWA / Secure Web Access VLAN (WireGuard / SWA)

# SVI IPs (CIDR). If you don't want core1 to host SVI for that VLAN, set to empty.
# IMPORTANT: make sure these IPs match the gateway expectations of your topology.
SVI_VLAN_ZT="192.168.10.1/24"    # example: gateway for 192.168.10.0/24 (ZT)
SVI_VLAN_IOT="192.168.30.1/24"   # example: gateway for 192.168.30.0/24 (IoT)
# For SWA (1001) either set to the subnet you want core1 to use, or leave empty
# if wan-node1 will be the gateway for that VLAN.
SVI_VLAN_SWA=""                   # e.g. "192.168.100.1/24" or leave empty

# Interfaces mapping on core1 (adjust if your SONiC naming differs)
TRUNK_IF="Ethernet1"   # link to wan-node1 -> must carry VLANs as tagged
LAN_IF="Ethernet4"     # host / linux1 (LAN) -> VLAN ${VLAN_ZT}
IOT_IFS=("Ethernet7" "Ethernet8")  # IoT hosts -> VLAN ${VLAN_IOT}

# -----------------------------
# Helper / safety
# -----------------------------
echo ">>> SONiC configuration for core1 starting..."
echo "VLANs: ZT=${VLAN_ZT}, IOT=${VLAN_IOT}, SWA=${VLAN_SWA}"
echo "Trunk -> ${TRUNK_IF}; LAN access -> ${LAN_IF}; IOT -> ${IOT_IFS[*]}"
echo "SVI ZT=${SVI_VLAN_ZT}, IOT=${SVI_VLAN_IOT}, SWA=${SVI_VLAN_SWA:-<none>}"

# Ensure we run with sudo where necessary (we call sudo on each config)
# Clear any leftover IPs on interfaces that will become L2 access ports
echo ">>> Removing L3 IPs from planned L2 ports (if present)..."
for IF in "${LAN_IF}" "${IOT_IFS[@]}"; do
  sudo config interface ip remove "$IF" all || true
done

# Also remove any IP assigned directly to the trunk interface, we want trunk only
echo ">>> Removing L3 IP from trunk interface ${TRUNK_IF} (if present)..."
sudo config interface ip remove "${TRUNK_IF}" all || true

# -----------------------------
# Create VLAN objects
# -----------------------------
echo ">>> Creating VLANs ${VLAN_ZT}, ${VLAN_IOT}, ${VLAN_SWA}..."
sudo config vlan add "${VLAN_ZT}" || true
sudo config vlan add "${VLAN_IOT}" || true
sudo config vlan add "${VLAN_SWA}" || true

# -----------------------------
# Configure trunk (tagged) membership on Ethernet1 -> to wan-node1
# -----------------------------
echo ">>> Configuring trunk (${TRUNK_IF}) as tagged member of VLANs..."
# For tagged membership do NOT use -u (untagged). Tagged == trunk ports.
sudo config vlan member add "${VLAN_ZT}" "${TRUNK_IF}" || true
sudo config vlan member add "${VLAN_IOT}" "${TRUNK_IF}" || true
sudo config vlan member add "${VLAN_SWA}" "${TRUNK_IF}" || true

# -----------------------------
# Configure access (untagged) ports
# -----------------------------
echo ">>> Configuring access ports (untagged) for LAN and IoT..."
# LAN -> VLAN_ZT (untagged)
sudo config vlan member add -u "${VLAN_ZT}" "${LAN_IF}" || true

# IoT -> VLAN_IOT (untagged)
for IF in "${IOT_IFS[@]}"; do
  sudo config vlan member add -u "${VLAN_IOT}" "${IF}" || true
done

# -----------------------------
# Create/assign SVIs (optional)
# -----------------------------
echo ">>> Creating/assigning SVI interfaces (only if IP provided)..."
if [ -n "${SVI_VLAN_ZT}" ]; then
  echo "Creating Vlan${VLAN_ZT} with IP ${SVI_VLAN_ZT}"
  sudo config interface ip add "Vlan${VLAN_ZT}" "${SVI_VLAN_ZT}" || true
  sudo config interface startup "Vlan${VLAN_ZT}" || true
else
  echo "Skipping Vlan${VLAN_ZT} SVI (no IP provided)."
fi

if [ -n "${SVI_VLAN_IOT}" ]; then
  echo "Creating Vlan${VLAN_IOT} with IP ${SVI_VLAN_IOT}"
  sudo config interface ip add "Vlan${VLAN_IOT}" "${SVI_VLAN_IOT}" || true
  sudo config interface startup "Vlan${VLAN_IOT}" || true
else
  echo "Skipping Vlan${VLAN_IOT} SVI (no IP provided)."
fi

if [ -n "${SVI_VLAN_SWA}" ]; then
  echo "Creating Vlan${VLAN_SWA} with IP ${SVI_VLAN_SWA}"
  sudo config interface ip add "Vlan${VLAN_SWA}" "${SVI_VLAN_SWA}" || true
  sudo config interface startup "Vlan${VLAN_SWA}" || true
else
  echo "Skipping Vlan${VLAN_SWA} SVI (no IP provided)."
fi

# -----------------------------
# Bring member ports up
# -----------------------------
echo ">>> Bringing access/trunk ports up..."
# Trunk and access ports
sudo config interface startup "${TRUNK_IF}" || true
sudo config interface startup "${LAN_IF}" || true
for IF in "${IOT_IFS[@]}"; do
  sudo config interface startup "${IF}" || true
done

# -----------------------------
# Save configuration
# -----------------------------
echo ">>> Saving SONiC configuration to disk..."
sudo config save -y

# -----------------------------
# Final info
# -----------------------------
echo ">>> Done. Verification commands to run on core1:"
echo "  show vlan brief"
echo "  show interfaces status"
echo "  show ip interface brief"
echo
echo "Notes:"
echo "- Ensure the IPs you set for the SVIs (SVI_VLAN_*) match the gateway addresses"
echo "  expected by your router/node configs (wan-node1)."
echo "- wan-node1 creates eth1.<VLAN> and assigns IPs there. If wan-node1 will be the"
echo "  gateway for a VLAN, leave the corresponding SVI_VLAN_* empty on core1."
echo ">>> Script finished."

