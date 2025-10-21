# --- Alpine IOT Client Dockerfile ---
#
# ## Description
#
# This Dockerfile builds a lightweight, Alpine-based container designed to simulate IoT devices.
# It can be built in two modes: a minimal version for core functionality, or a full
# version with an extended suite of network troubleshooting tools.
#
# ## Features
#
# - **IoT Simulation:** Includes `mosquitto-clients` for publishing and subscribing to MQTT topics.
# - **Conditional Packages:** Use the `include_network_tools` build-arg to add extra network utilities.
# - **Process Management:** Uses `supervisord` to robustly manage background services.
# - **Secure SSH:** Runs a hardened SSH server (key-auth only) that dynamically binds to the container's IP.
# - **User Access:** Provides a pre-configured `admin` user with passwordless `sudo`.
#
# ## Build
#
#   # Minimal build (default)
#   docker build -t iot-client-alpine:minimal .
#
#   # Full build (with extra network tools)
#   docker build --build-arg include_network_tools=true -t iot-client-alpine:full .

# ## Runtime
#
#   to dynamically add services to the container, bind a supervisord.conf file to the container
#       docker run -d --name iot_instance_1 -v /home/user/admin/configs/run_my_service.conf /etc/supervisor/conf.d/supervisor.conf
#
# ------------------------------------

FROM alpine:latest

# Define a build-time argument to control the installation of optional tools.
# It defaults to 'false' for a minimal image.
ARG include_network_tools=false

# --- Install base packages ---
# These packages are essential for the container's core functionality.
RUN apk add --no-cache \
    supervisor \
    openssh \
    bash \
    sudo \
    iputils \
    mosquitto-clients \
    bind-tools \
    iproute2

# --- Conditionally install additional network tools ---
# This block only runs if the build argument 'include_network_tools' is set to 'true'.
RUN if [ "$include_network_tools" = "true" ]; then \
        echo "--- Installing additional network tools ---" && \
        apk add --no-cache \
            traceroute \
            curl \
            wget \
            net-tools \
            tcpdump; \
    else \
        echo "--- Skipping additional network tools (minimal build) ---"; \
    fi

# --- Create and configure 'admin' user ---
RUN adduser -D -s /bin/bash -u 1000 admin && \
    echo "admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo 'admin:SONiC@2025' | chpasswd && \
    echo 'root:SONiC@2025' | chpasswd

# --- Configure SSH Server ---
RUN ssh-keygen -A && \
    sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/^#?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- Set up SSH keys ---
# (Your key setup blocks go here)
RUN mkdir -p /home/admin/.ssh && \
    chown -R admin:admin /home/admin/.ssh && \
    chmod 700 /home/admin/.ssh && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh
COPY authorized_keys /home/admin/.ssh/authorized_keys
COPY authorized_keys /root/.ssh/authorized_keys
RUN chown admin:admin /home/admin/.ssh/authorized_keys && \
    chmod 600 /home/admin/.ssh/authorized_keys && \
    chown root:root /root/.ssh/authorized_keys && \
    chmod 600 /root/.ssh/authorized_keys

# --- Add the dynamic sshd wrapper script ---
COPY start-sshd-dynamic.sh /usr/local/bin/start-sshd-dynamic.sh
RUN chmod +x /usr/local/bin/start-sshd-dynamic.sh

# --- Configure Supervisor ---
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Expose the SSH port
EXPOSE 22

# Start supervisord to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]