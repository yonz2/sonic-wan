
---
### 2. `README-iot-client.md`

This file contains the documentation for the Alpine-based `iot-client`.

```markdown
# Alpine IOT Client (`iot-client-alpine`)

This container is a lightweight, Alpine-based client designed to simulate IoT devices. Its primary role is to inject MQTT messages, but it also serves as a full-featured network diagnostics client.

It uses `supervisord` for robust process management and features a hardened SSH server that dynamically binds to the container's primary IP address.

### Prerequisites

Before building, ensure you have the following files in your directory:
* `Dockerfile` (The Alpine version)
* `supervisord.conf`
* `start-sshd-dynamic.sh`
* `authorized_keys` (Containing your public SSH key)

### Building the Image

This image can also be built in two versions.

#### Minimal Version
This version includes the MQTT client and essential network tools.

```sh
docker build -t iot-client-alpine:minimal .
````

#### Full Version (with extra network tools)

This version adds `curl`, `wget`, `traceroute`, `net-tools`, and `tcpdump`.

```sh
docker build --build-arg include_network_tools=true -t iot-client-alpine:full .
```

### Running the Container

Run the container, mapping a different host port (e.g., `2223`) to avoid conflicts if the Debian client is also running.

```sh
docker run -d --name my-iot-client -p 2223:22 iot-client-alpine:minimal
```

*(Replace `:minimal` with `:full` if you built the full version).*

### Verification and Testing

1.  **Check Container Status:**

    ```sh
    docker ps
    ```

    *(You should see `my-iot-client` with status "Up").*

2.  **Inspect Startup Logs:**

    ```sh
    docker logs my-iot-client
    ```

    *(Confirm the SSH script ran successfully).*

3.  **Connect via SSH:**
    Use the `admin` user and the host port you mapped for this container.

    ```sh
    ssh admin@localhost -p 2223
    ```

4.  **Test Commands Inside:**
    Verify the IoT and standard tools.

    ```sh
    mosquitto_pub --help
    ping -c 3 google.com
    sudo whoami
    ```

<!-- end list -->

