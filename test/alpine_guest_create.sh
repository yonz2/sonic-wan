#!/bin/bash

set -e
echo "Create Alpine Linux VM Guest"
echo " "

# Get the latest Alpine Linux iso Image:
#     Check https://alpinelinux.org/downloads/ for latest version available (08.10.2025)
LIBVIRT_PATH=/var/lib/libvirt/boot
ISO_IMAGE_URL="https://dl-cdn.alpinelinux.org/alpine/v3.21/releases/x86_64/alpine-extended-3.21.5-x86_64.iso"
VM_NAME="alpine-test-client"
RAM_MB="512" # Alpine is very lightweight
VCPUS="1"
BRIDGE_IF="br0"
DISK_IMAGE="/var/lib/libvirt/images/alpine-guest.qcow2"



# Get the name of the image from the URL
ISO_IMAGE=${ISO_IMAGE_URL##*/}

LIBVIRT_IMG=$LIBVIRT_PATH/$ISO_IMAGE

if [ ! -e $LIBVIRT_IMG ]; then
    echo "File $LIBVIRT_IMG does not exist. Downloading file..."
    wget $ISO_IMAGE_URL
    echo "Iso Image $ISO_IMAGE Downloaded"

    sudo mv $ISO_IMAGE $LIBVIRT_IMG
    sudo chmod 755 $LIBVIRT_IMG
    sudo chown $USER:libvirt $LIBVIRT_IMG
    echo "and moved to $LIBVIRT_IMG"


else
    echo "File $LIBVIRT_IMG  exists."virt
fi

# exit

sudo virt-install \
    --name "$VM_NAME" \
    --vcpus "$VCPUS" \
    --os-variant alpinelinux3.21 \
    --memory "$RAM_MB" \
    --disk size=8 \
    --cdrom $LIBVIRT_IMG \
    --check all=off \
    --disk path="$DISK_IMAGE",format=qcow2 \
    --network bridge="$BRIDGE_IF",model=virtio \
    --graphics none \
    --console pty,target_type=serial \
    --noautoconsole


echo "Login using \"root\""
echo "Followed by \"setup-alpine\" "



