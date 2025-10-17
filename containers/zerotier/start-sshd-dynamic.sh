#!/bin/bash
# This script calculates the container's IP and starts sshd listening only on that IP.
# It is designed to be called by supervisord.

echo "Configuring dynamic ListenAddress for sshd..."
sleep 1 # Wait for the network to be ready, just in case.

# Get the IPv4 address of eth0
MGMT_IP4_ADDRESS=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

if [ -z "$MGMT_IP4_ADDRESS" ]; then
    echo "ERROR: Could not determine IP address for eth0. Exiting."
    exit 1
fi

# Construct a corresponding IPv6 address (optional, based on your logic)
MGMT_IP4_PREFIX=$(echo $MGMT_IP4_ADDRESS | cut -d. -f1-3)
MGMT_IP6_ADDRESS="3fff:${MGMT_IP4_PREFIX//./:}::${MGMT_IP4_ADDRESS##*.}"

echo "--> sshd will listen on: $MGMT_IP4_ADDRESS and $MGMT_IP6_ADDRESS"

# Use 'exec' to replace the script process with the sshd process.
# This is critical for supervisord to be able to manage sshd correctly.
# The -D and -e flags keep sshd in the foreground and log to stderr.
exec /usr/sbin/sshd -D -e \
    -o "ListenAddress $MGMT_IP4_ADDRESS" \
    -o "ListenAddress $MGMT_IP6_ADDRESS"
