# --- Linux Client Dockerfile ---
#
# ## Description
#
# This Dockerfile builds a versatile Linux client container based on Debian bookworm-slim.
# It is designed as a secure jump box or network troubleshooting client. It can be built
# in a minimal mode or a full mode with extra network utilities.
#
# ## Build
#
#   # Minimal build (default)
#   docker build -t linux-client:minimal .
#
#   # Full build (with extra network tools)
#   docker build --build-arg include_network_tools=true -t linux-client:full .
#
# ---------------------------------

FROM debian:bookworm-slim

# Define a build-time argument to control the installation of optional tools.
# It defaults to 'false' for a minimal image.
ARG include_network_tools=false

# --- Install base packages ---
# These packages are essential for the container's core functionality.
RUN apt-get update && apt-get install -y --no-install-recommends \
    supervisor \
    sudo \
    openssh-server \
    iputils-ping \
    dnsutils \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# --- Conditionally install additional network tools ---
# This block only runs if the build argument 'include_network_tools' is set to 'true'.
RUN if [ "$include_network_tools" = "true" ]; then \
        echo "--- Installing additional network tools ---" && \
        apt-get update && \
        apt-get install -y --no-install-recommends \
            curl \
            wget \
            traceroute \
            net-tools \
            tcpdump \
        && rm -rf /var/lib/apt/lists/*; \
    else \
        echo "--- Skipping additional network tools (minimal build) ---"; \
    fi

# ... the rest of your Dockerfile remains the same ...

# --- Create and configure 'admin' user ---
RUN useradd -m -u 1000 -s /bin/bash admin && \
    echo "admin ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
    echo -n 'admin:SONiC@2025' | chpasswd && \
    echo -n 'root:SONiC@2025' | chpasswd

# --- Configure SSH Server ---
RUN /usr/bin/ssh-keygen -A && \
    mkdir -p /run/sshd && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- Set up SSH keys ---
RUN mkdir -p /home/admin/.ssh && \
    chown -R admin:admin /home/admin/.ssh && \
    chmod 700 /home/admin/.ssh && \
    mkdir -p /root/.ssh && \
    chown -R root:root /root/.ssh && \
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
