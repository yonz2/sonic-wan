#!/bin/bash
# The script is a simple bash script that gets the IP address of the eth0 interface and starts the sshd daemon with the IP address as the ListenAddress. 

sleep 1 # Wait for the network to be ready

# Get the IPv4 address of eth0
MGMT_IP4_ADDRESS=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

# Extract the first three octets of the IPv4 address
MGMT_IP4_PREFIX=$(echo $MGMT_IP4_ADDRESS | cut -d. -f1-3)

# Construct the IPv6 address
MGMT_IP6_ADDRESS="3fff:${MGMT_IP4_PREFIX//./:}::${MGMT_IP4_ADDRESS##*.}"

export MGMT_IP4_ADDRESS
export MGMT_IP6_ADDRESS
echo "Management IP addresses: $MGMT_IP4_ADDRESS / $MGMT_IP6_ADDRESS"


# Start sshd with the IP address as ListenAddress
/usr/sbin/sshd -o "ListenAddress $MGMT_IP4_ADDRESS" -o "ListenAddress $MGMT_IP6_ADDRESS"
