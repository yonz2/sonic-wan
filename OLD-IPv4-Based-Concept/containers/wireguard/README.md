# WireGuard Container Image

This document outlines the procedure for deploying the official `linuxserver/wireguard` Docker image within this project, specifically for use on a SONiC virtual machine.

This method does not involve building a new image from a `Dockerfile`. Instead, the pre-built image is pulled from Docker Hub, archived, **compressed**, and then transferred to the target system where it is **decompressed** and loaded into the local Docker environment.

---

## Image Source

The image used is the standard, unmodified `linuxserver/wireguard` image.

* **Docker Hub Registry**: `linuxserver/wireguard`
* **Official Page**: [https://hub.docker.com/r/linuxserver/wireguard](https://hub.docker.com/r/linuxserver/wireguard)

---

## Deployment Process

The deployment involves several steps, moving the image from an internet-connected machine to the isolated SONiC VM.

### 1. Pull the Image

On a machine with internet access and Docker installed, pull the latest version of the image from Docker Hub.

```bash
docker pull linuxserver/wireguard:latest
```

### 2. Save and Compress the Image

First, package the pulled image into a `.tar` file. Then, compress this archive using `gzip` to reduce its size for faster transfer.

```bash
# Save the image to a tarball
docker save -o wireguard.tar linuxserver/wireguard:latest

# Compress the tarball with gzip
gzip wireguard.tar
```
This process will create a single compressed file named `wireguard.tar.gz`.

### 3. Transfer the Archive

Copy the compressed `wireguard.tar.gz` file to the target SONiC VM. You can use tools like `scp`, a shared folder, or any other file transfer method suitable for your environment.

### 4. Decompress and Load the Image

Once the archive is on the SONiC VM, you must first decompress it and then load the resulting `.tar` file into Docker.

```bash
# Decompress the file
gunzip wireguard.tar.gz

# Load the image from the tar archive
docker load -i wireguard.tar
```

After this step, the `linuxserver/wireguard:latest` image will be available locally and can be used to start a container on the SONiC VM.

---

## Configuration

For details on how to run and configure the container (e.g., setting up peer configurations, port mappings, and volumes), please refer to the comprehensive documentation on the official [linuxserver/wireguard Docker Hub page](https://hub.docker.com/r/linuxserver/wireguard).
