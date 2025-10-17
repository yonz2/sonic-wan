# Container Images

This directory contains the `Dockerfiles` used to build the custom container images for this project. Each image serves a specific role within the network simulations.

---

### 1. `alpine-iot-node`

* **Base Image**: `alpine`
* **Description**: A minimal image equipped with basic networking utilities (like `iproute2`, `ping`, `curl`) and an MQTT client (`mosquitto-clients`).
* **Intended Use**: Designed to function as a lightweight IoT leaf node in Containerlab network topologies.

---

### 2. `debian-client-slim`

* **Base Image**: `debian:bookworm-slim`
* **Description**: A lean Debian-based image that includes a standard set of networking tools.
* **Intended Use**: Serves as a simulated user client or general-purpose host within Containerlab network simulations.

---

### 3. `zerotier`

* **Base Image**:  `debian:bookworm-slim`
* **Description**: A container running the ZeroTier One client. It is configured to use a persistent identity and static network interface names, which are supplied via a mounted volume.
* **Intended Use**: Acts as a secure network node that can connect to virtual networks across different environments.

### 3. `wireguard`

* **Base Image**:  `linuxserver/wireguard` (See also: [linuxserver/wireguard](https://hub.docker.com/r/linuxserver/wireguard) )
* **Description**: WireGuard®⁠ is an extremely simple yet fast and modern VPN that utilizes state-of-the-art cryptography. It aims to be faster, simpler, leaner, and more useful than IPsec, while avoiding the massive headache. It intends to be considerably more performant than OpenVPN. WireGuard is designed as a general purpose VPN for running on embedded interfaces and super computers alike, fit for many different circumstances. Initially released for the Linux kernel, it is now cross-platform (Windows, macOS, BSD, iOS, Android) and widely deployable. It is currently under heavy development, but already it might be regarded as the most secure, easiest to use, and simplest VPN solution in the industry.
  
* **Intended Use**: In this setup the WireGuard Container is used to simulate a Secure Web Access Gateway (part of the Secure WAN POC)
