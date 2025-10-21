#!/bin/bash

# ==============================================================================
# SONiC Secure WAN - Unit Test Script
# ==============================================================================
# This script runs a series of network connectivity and routing tests against
# the SONiC VM from an external test client container.
#
# Usage:
#   1. Ensure the 'sonic-test-client' container is running.
#   2. Make this script executable: chmod +x run_sonic_tests.sh
#   3. Run it from your KVM host: ./run_sonic_tests.sh
# ==============================================================================

set -e

# --- Configuration ---
# The name of your running test client container.
TEST_CONTAINER="sonic-test-client"

# --- IP Addresses to Test ---
# The gateway IP for the corporate user VLAN (steered to WireGuard).
VLAN10_GATEWAY="192.168.10.1"

# The gateway IP for the IoT VLAN (steered to ZeroTier).
VLAN30_GATEWAY="192.168.30.1"

# A public IP address on the internet to test the WireGuard tunnel.
PUBLIC_IP="8.8.8.8"

# The IP address of another node on your ZeroTier network.
# IMPORTANT: You must change this to a real IP on your ZT network.
ZEROTIER_PEER_IP="10.147.20.1" # <--- CHANGE THIS

# --- Helper Functions ---
print_header() {
  echo ""
  echo "=============================================================================="
  echo " $1"
  echo "=============================================================================="
}

run_test() {
  local description="$1"
  local command_to_run="$2"
  echo -n "▶️  TEST: $description..."
  if docker exec "$TEST_CONTAINER" /bin/bash -c "$command_to_run"; then
    echo " ✅ PASSED"
  else
    echo " ❌ FAILED"
    # Optionally exit on first failure:
    # exit 1
  fi
}

# ==============================================================================
# --- TEST SUITE 1: Corporate User (VLAN 10) -> WireGuard Tunnel ---
# ==============================================================================
print_header "Running Test Suite 1: Corporate User (VLAN 10) via WireGuard"

# Configure the test client for VLAN 10
docker exec "$TEST_CONTAINER" ip addr flush dev eth0
docker exec "$TEST_CONTAINER" ip addr add 192.168.10.100/24 dev eth0
docker exec "$TEST_CONTAINER" ip route replace default via "$VLAN10_GATEWAY"
echo "✅ Test client configured for VLAN 10 (192.168.10.100/24)"

# --- Run the tests ---
run_test "Ping VLAN 10 Gateway" "ping -c 2 $VLAN10_GATEWAY"
run_test "Ping Public IP ($PUBLIC_IP)" "ping -c 2 $PUBLIC_IP"
run_test "Traceroute to Public IP (should show one hop)" "traceroute -n -w 1 -q 1 $PUBLIC_IP | grep -q '1'"
run_test "DNS Resolution (google.com)" "nslookup google.com"
run_test "HTTP Connectivity (google.com)" "curl -s --head http://www.google.com | head -n 1 | grep -q '200 OK'"

# --- Negative Test: Should NOT be able to reach the ZeroTier peer directly ---
print_header "Running Negative Test: VLAN 10 Client Should NOT Reach ZeroTier Peer"
run_test "Ping ZeroTier Peer ($ZEROTIER_PEER_IP)" "! ping -c 2 $ZEROTIER_PEER_IP"


# ==============================================================================
# --- TEST SUITE 2: IoT Device (VLAN 30) -> ZeroTier Tunnel ---
# ==============================================================================
print_header "Running Test Suite 2: IoT Device (VLAN 30) via ZeroTier"

# Configure the test client for VLAN 30
docker exec "$TEST_CONTAINER" ip addr flush dev eth0
docker exec "$TEST_CONTAINER" ip addr add 192.168.30.100/24 dev eth0
docker exec "$TEST_CONTAINER" ip route replace default via "$VLAN30_GATEWAY"
echo "✅ Test client configured for VLAN 30 (192.168.30.100/24)"

# --- Run the tests ---
run_test "Ping VLAN 30 Gateway" "ping -c 2 $VLAN30_GATEWAY"
run_test "Ping ZeroTier Peer ($ZEROTIER_PEER_IP)" "ping -c 2 $ZEROTIER_PEER_IP"
run_test "Traceroute to ZeroTier Peer" "traceroute -n -w 1 -q 1 $ZEROTIER_PEER_IP"

# --- Negative Test: Should NOT be able to reach the public internet ---
print_header "Running Negative Test: VLAN 30 Client Should NOT Reach Public Internet"
run_test "Ping Public IP ($PUBLIC_IP)" "! ping -c 2 $PUBLIC_IP"

echo ""
echo "🎉 All tests completed."
