
### 1\. `README-linux-client.md`

This file contains the documentation for the Debian-based `linux-client`.

````markdown
# Debian Linux Client (`linux-client`)

This container is a versatile Linux client based on Debian bookworm-slim. It's designed to act as a secure jump box or network troubleshooting client for use in containerized environments.

It uses `supervisord` for robust process management and features a hardened SSH server that dynamically binds to the container's primary IP address.

### Prerequisites

Before building, ensure you have the following files in your directory:
* `Dockerfile` (The Debian version)
* `supervisord.conf`
* `start-sshd-dynamic.sh`
* `authorized_keys` (Containing your public SSH key)

### Building the Image

You can build two versions of the image using a build-time argument.

#### Minimal Version
This version includes essential tools like `ping` and `nslookup`.

```sh
docker build -t linux-client:minimal .
````

#### Full Version (with extra network tools)

This version adds `curl`, `wget`, `traceroute`, `net-tools`, and `tcpdump`.

```sh
docker build --build-arg include_network_tools=true -t linux-client:full .
```

### Running the Container

Run the container in detached mode and map a host port (e.g., `2222`) to the container's SSH port (22).

```sh
docker run -d --name my-linux-client -p 2222:22 linux-client:minimal
```

*(Replace `:minimal` with `:full` if you built the full version).*

### Verification and Testing

Follow these steps to ensure your container is running correctly.

1.  **Check Container Status:**

    ```sh
    docker ps
    ```

    *(You should see `my-linux-client` with status "Up").*

2.  **Inspect Startup Logs:**

    ```sh
    docker logs my-linux-client
    ```

    *(Look for the line `--> sshd will listen on: ...` to confirm the SSH script ran).*

3.  **Connect via SSH:**
    Use the `admin` user and the host port you mapped.

    ```sh
    ssh admin@localhost -p 2222
    ```

    > **Note:** This requires your private SSH key to match the public key in the `authorized_keys` file.

4.  **Test Commands Inside:**
    Once logged in, verify the tools and `sudo` access.

    ```sh
    ping -c 3 google.com
    nslookup google.com
    sudo whoami
    ```

<!-- end list -->

````
