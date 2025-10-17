

# SONiC VM Setup Automation

This repository contains a collection of bash scripts to automate the deployment and initial configuration of a [SONiC (Software for Open Networking in the Cloud)](https://sonic-net.github.io/SONiC/) virtual machine on an Ubuntu/Debian host using KVM.

The scripts streamline the process from preparing the host environment to configuring the running SONiC instance.

-----

## Scripts Overview

This project includes the following scripts, designed to be run in a specific order.

### `enable-network-bridge.sh`

  * **Purpose**: Configures a network bridge (`br0`) on the host machine using `netplan`. This is a prerequisite for allowing the VM to connect directly to the local network.
  * **Target**: HOST Machine 🌐
  * **Usage**:
    ```bash
    # Provide your host's physical network interface name
    sudo ./enable-network-bridge.sh <interface_name>
    ```

### `create_sonic_vm.sh`

  * **Purpose**: Creates and starts the SONiC VM using `virt-install`. It imports a pre-existing `.qcow2` disk image.
  * **Target**: HOST Machine 🌐
  * **Usage**:
    ```bash
    # With the default disk image path
    sudo ./create_sonic_vm.sh

    # With a custom disk image path
    sudo ./create_sonic_vm.sh /path/to/sonic.qcow2
    ```

### `configure_sonic_vm.sh`

  * **Purpose**: Performs the initial configuration of the running SONiC VM. This script automates SSH key setup, DNS configuration, Git installation, and deployment of custom Docker images.
  * **Target**: HOST Machine 🌐
  * **Usage**:
    ```bash
    ./configure_sonic_vm.sh
    ```

### `dns-config.sh`

  * **Purpose**: A helper script that configures DNS inside the SONiC VM to enable outbound internet access. It is called automatically by `configure_sonic_vm.sh` and is not typically run by itself.
  * **Target**: SONiC VM ⚙️

-----

## Recommended Workflow

To set up a complete SONiC VM from scratch, follow these steps:

1.  **Prepare the Host Network**: Run `enable-network-bridge.sh` once on your host to set up the required networking.
    ```bash
    sudo ./enable-network-bridge.sh enp3s0
    ```
2.  **Create the VM**: Run `create_sonic_vm.sh` to create and launch the SONiC instance.
    ```bash
    sudo ./create_sonic_vm.sh
    ```
3.  **Configure the VM**: Once the VM is running and has an IP address, run `configure_sonic_vm.sh` from the host to apply the initial settings.
    ```bash
    ./configure_sonic_vm.sh
    ```
