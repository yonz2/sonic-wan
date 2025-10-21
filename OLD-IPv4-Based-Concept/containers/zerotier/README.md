# ZeroTier Docker Container

This Docker container runs the ZeroTier One client. It is configured to use a **persistent identity** and **static network interface names**, making it suitable for deployments where predictable node addresses and interface identifiers are necessary.

Configuration is managed by mounting a host directory containing predefined files into the container.

---

## Prerequisites

Before launching the container, you must prepare a configuration directory on the host system. This directory will be mounted to `/var/lib/zerotier-one` inside the container.

Create a directory on your host, for example, `~/zerotier-config`, and place the following files inside it.

### Required Files

* **`identity.public`** & **`identity.secret`**: These two files define the permanent identity of your ZeroTier node. They must be generated beforehand using the `zerotier-idtool` utility, which is part of the standard ZeroTier package.
    ```bash
    # Run this on a machine with zerotier-one installed to generate the files
    zerotier-idtool generate identity.secret identity.public
    ```

* **`devicemap`**: This file maps a ZeroTier Network ID to a static interface name within the container. This prevents the interface from being named randomly (e.g., `zt` followed by random characters).
    * **Format**: `NETWORK_ID=INTERFACE_NAME`
    * **Example `devicemap` file**:
        ```
        # Maps network a84ac5c10a4eafb4 to the interface named 'zt0'
        a84ac5c10a4eafb4=zt0
        ```

### Optional File

* **`local.conf`**: This JSON file allows you to override default settings. A common use is to change the default listening port (`9993/udp`) if it conflicts with other services.
    * **Example `local.conf` to change the port to `9994`**:
        ```json
        {
            "settings": {
                "primaryPort": 9994
            }
        }
        ```

---

## Building the Docker Image

From the root of this repository (where the `Dockerfile` is located), run the following command to build the Docker image.

```bash
docker build -t my-zerotier:latest .
```

This will create a local image named `my-zerotier` with the tag `latest`.

---

## Usage

### 1. Run the Container

Use the following command to run the container. Ensure you provide the correct path to your host configuration directory. The container requires elevated privileges to manage network interfaces (`--device=/dev/net/tun` and `--cap-add=NET_ADMIN`).

```bash
docker run -d \
  --name zerotier-node \
  --device=/dev/net/tun \
  --cap-add=NET_ADMIN \
  -v /path/to/your/zerotier-config:/var/lib/zerotier-one \
  -p 9993:9993/udp \
  my-zerotier:latest
```

**Note**: If you used `local.conf` to change the port, you must adjust the port mapping flag accordingly. For example, for port `9994`, use `-p 9994:9994/udp`.

### 2. Join a Network

Once the container is running, you can join a ZeroTier network using `docker exec`.

```bash
docker exec zerotier-node zerotier-cli join <YOUR_NETWORK_ID>
```

The client will use the identity you provided and, thanks to the `devicemap` file, will create a network interface with the name you specified.

---

## Exporting the Image

To transfer this Docker image to another system without using a container registry (for example, to a machine without internet access), you can save it as a `tar` archive.

### 1. Save the Image

Use the `docker save` command to create a `.tar` file from the image.

```bash
# Save the image
docker save -o my-zerotier.tar my-zerotier:latest

# Compress the tarball with gzip
gzip my-zerotier.tar

```

This command packages the image `my-zerotier:latest` into a file named `my-zerotier.tar` in your current directory.

### 2. Load the Image on Another Host

Copy the `.tar` file to the target machine and use the `docker load` command to import it into the local Docker image cache.

```bash
# Decompress the file
gunzip my-zerotier.tar.gz

docker load -i my-zerotier.tar

```

After loading, you can run the container on the new host as described in the **Usage** section.