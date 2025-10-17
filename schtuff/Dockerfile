# ==============================================================================
# Dockerfile for a Policy-Based Linux Router (Supervisor Edition)
# ==============================================================================
# Template: Generic Linux Client (debian:bookworm-slim)
# Manages: SSH, ZeroTier, and the routing configuration via Supervisor.
# ==============================================================================

FROM debian:bookworm-slim

# --- Install base packages for Router Functionality ---
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    openresolv \
    supervisor \
    sudo \
    openssh-server \
    iputils-ping \
    iptables \
    dnsutils \
    iproute2 \
    vlan \
    wireguard-tools \
    curl \
    gpg \
    wget \
    jq \
    traceroute \
    net-tools \
    tcpdump \
    && rm -rf /var/lib/apt/lists/*

# ------------------------------------------------------------------------------
# --- Configure Custom Routing Tables ---
# Add human-readable names for our policy routing tables. This allows scripts
# to reference 'zerotier_wan' and 'swa_wan' instead of magic numbers.
RUN echo "100 zerotier_wan" >> /etc/iproute2/rt_tables && \
    echo "200 swa_wan" >> /etc/iproute2/rt_tables
# ------------------------------------------------------------------------------

# --- Install ZeroTier ---
# ------------------------------------------------------------------------------
# --- Install ZeroTier (REVISED - MORE ROBUST METHOD) ---
# This method uses ZeroTier's official APT repository for a more reliable install.
RUN curl -s 'https://raw.githubusercontent.com/zerotier/ZeroTierOne/main/doc/contact%40zerotier.com.gpg' | gpg --dearmor | tee /usr/share/keyrings/zerotier-archive-keyring.gpg >/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/zerotier-archive-keyring.gpg] https://download.zerotier.com/debian/bookworm bookworm main" | tee /etc/apt/sources.list.d/zerotier.list && \
    apt-get update && \
    apt-get install -y zerotier-one
# ------------------------------------------------------------------------------

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
RUN mkdir -p /home/admin/.ssh && chown -R admin:admin /home/admin/.ssh && chmod 700 /home/admin/.ssh
RUN mkdir -p /root/.ssh && chown -R root:root /root/.ssh && chmod 700 /root/.ssh
COPY authorized_keys /home/admin/.ssh/authorized_keys
COPY authorized_keys /root/.ssh/authorized_keys
RUN chown admin:admin /home/admin/.ssh/authorized_keys && chmod 600 /home/admin/.ssh/authorized_keys
RUN chown root:root /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys

# Patch the WireGuard script "wg-quick" to work inside of a container
RUN sed -i 's|\[\[ $proto == -4 \]\] && cmd sysctl -q net\.ipv4\.conf\.all\.src_valid_mark=1|[[ $proto == -4 ]] \&\& [[ $(sysctl -n net.ipv4.conf.all.src_valid_mark) != 1 ]] \&\& cmd sysctl -q net.ipv4.conf.all.src_valid_mark=1|' /usr/bin/wg-quick && \

# --- Add Supervisor, SSH, and Router scripts ---
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-sshd-dynamic.sh /usr/local/bin/start-sshd-dynamic.sh
COPY configure_router.sh /usr/local/bin/configure_router.sh
RUN chmod +x /usr/local/bin/start-sshd-dynamic.sh && \
    chmod +x /usr/local/bin/configure_router.sh

# Expose the standard SSH port
EXPOSE 22

# Start supervisord to manage all services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]