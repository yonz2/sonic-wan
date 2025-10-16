#!/bin/bash
#
# A robust script to deploy WireGuard and/or ZeroTier containers on SONiC.
#

# --- Configuration ---
# Exit immediately if a command exits with a non-zero status.
set -e

# --- Functions ---

# Prints the usage instructions for the script.
usage() {
    echo "Usage: $0 [wireguard|zerotier|both]"
    echo "  - wireguard: Deploys only the WireGuard container."
    echo "  - zerotier:  Deploys only the ZeroTier container."
    echo "  - both:      Deploys both containers (default)."
    exit 1
}

# Sets up the required sysctl kernel parameter for WireGuard.
# The function is idempotent and safe to run multiple times.
setup_sysctl() {
    local config_file="/etc/sysctl.d/99-wireguard.conf"
    echo "INFO: Checking kernel parameters for WireGuard..."

    if [ ! -f "$config_file" ]; then
        echo "INFO: Configuration file not found. Creating $config_file..."
        echo "net.ipv4.conf.all.src_valid_mark=1" | sudo tee "$config_file" > /dev/null
    else
        echo "INFO: Configuration file $config_file already exists."
    fi

    echo "INFO: Applying sysctl settings from all configuration files..."
    sudo sysctl --system
    echo "INFO: Kernel parameters are set."
}

# Stops, removes, and deploys the WireGuard container.
deploy_wireguard() {
    echo "--- Deploying WireGuard ---"
    
    # Stop and remove any previous instance of the container, ignoring errors if it doesn't exist.
    echo "INFO: Removing existing WireGuard container (if any)..."
    sudo docker stop wireguard >/dev/null 2>&1 || true
    sudo docker rm wireguard >/dev/null 2>&1 || true

    echo "INFO: Launching new WireGuard container..."
    # Note: Ensure your wg0.conf is located in /etc/wireguard on the host.
    sudo docker run -d \
      --name wireguard \
      --network=host \
      --cap-add=NET_ADMIN \
      --cap-add=SYS_MODULE \
      --device=/dev/net/tun \
      -e TZ=Europe/Berlin \
      -v /etc/wireguard:/config \
      -v /var/log/wireguard:/var/log/wireguard \
      -v /lib/modules:/lib/modules \
      --restart=unless-stopped \
      linuxserver/wireguard:latest

    echo "SUCCESS: WireGuard container has been started."
}

# Stops, removes, and deploys the ZeroTier container.
deploy_zerotier() {
    echo "--- Deploying ZeroTier ---"

    # Stop and remove any previous instance of the container, ignoring errors if it doesn't exist.
    echo "INFO: Removing existing ZeroTier container (if any)..."
    sudo docker stop zerotier >/dev/null 2>&1 || true
    sudo docker rm zerotier >/dev/null 2>&1 || true

    echo "INFO: Launching new ZeroTier container..."
    sudo docker run -d \
      --name zerotier \
      --network=host \
      --cap-add=NET_ADMIN \
      --cap-add=SYS_MODULE \
      --device=/dev/net/tun \
      -v /var/lib/zerotier-one:/var/lib/zerotier-one \
      --restart=unless-stopped \
      zerotier:wan # Using your custom-built image

    echo "SUCCESS: ZeroTier container has been started."
}


# --- Main Script Logic ---

# Default to deploying both if no argument is given
DEPLOY_TARGET=${1:-both}

case "$DEPLOY_TARGET" in
    wireguard)
        setup_sysctl
        deploy_wireguard
        ;;
    zerotier)
        # sysctl is not needed for ZeroTier, but we run it anyway if it's the only one.
        setup_sysctl
        deploy_zerotier
        ;;
    both)
        setup_sysctl
        deploy_wireguard
        deploy_zerotier
        ;;
    *)
        echo "ERROR: Invalid argument '$DEPLOY_TARGET'."
        usage
        ;;
esac

echo "--- Deployment Complete ---"
