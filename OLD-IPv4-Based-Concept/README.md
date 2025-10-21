# SONiC Secure WAN Integration (POC)

**Author:** Yonz / Net-Innovate Solutions GmbH  
**License:** The Unlicense  
**Version:** 2025-10-16

---

## Overview

This repository provides all scripts and configurations required to extend a **SONiC network OS** instance with WAN tunneling and policy-based routing capabilities.

The result is a **Secure WAN Edge Router**, capable of:
- Running **ZeroTier** for *site-to-site networking* between distributed sites.
- Running **WireGuard (or commercial SWG connectors)** for *secure internet access (SWA)*.
- Steering traffic intelligently between the two WAN paths using *policy-based routing (PBR)*.

The setup is designed to be baked into a SONiC virtual machine image before it is containerized using **vrnetlab** and deployed into a **Containerlab**-based test topology.

---

## Functional Overview

### 🧩 Core Idea

This project extends SONiC from a pure L2/L3 switch into a **Secure Edge Router**, combining:
- Traditional switching and routing (handled by SONiC)
- Tunnel-based WAN connectivity (handled by containers)
- Policy-based routing logic to separate *site traffic* from *internet traffic*

```
                         ┌──────────────────────────┐
                         │     SONiC Secure WAN     │
                         │        (core1)           │
                         ├──────────────────────────┤
                         │ L2/L3 Switching (SONiC)  │
                         │ VLANs, SVIs, VRFs        │
                         ├──────────────────────────┤
                         │   Containers (Docker)    │
                         │   ┌───────────┬────────┐ │
                         │   │ WireGuard │ ZT-WAN │ │
                         │   └───────────┴────────┘ │
                         ├──────────────────────────┤
                         │  Linux Policy Routing    │
                         │  VLAN → Tunnel Steering  │
                         └──────────────────────────┘
```

---

## Tunnel Roles

### 🌐 WireGuard — Secure Web Access Tunnel

- **Purpose:** Default egress for all Internet-bound traffic.  
- **Production Equivalent:** In a real-world setup, this tunnel would be replaced by a **Secure Web Gateway (SWG)** connector such as:
  - *Zscaler Internet Access (ZIA)*
  - *Cloudflare Gateway*
  - *Netskope Secure Web Access*

- **Current Role (POC):**
  - Acts as a stand-in SWA tunnel.
  - All Internet traffic from internal VLANs (e.g. user VLANs, IoT VLANs) is routed via `wg0`.
  - Implements basic NAT and forwarding logic.

### 🔄 ZeroTier — Site-to-Site Overlay Tunnel

- **Purpose:** Secure, full-mesh, private connectivity between distributed sites.
- **Use Case Example:**
  - IoT sensors at remote sites report data to a central collector.
  - Controllers or monitoring systems can reach all sites directly via the ZeroTier overlay.
- **Interface:** Appears as `zt0` inside SONiC.
- **Identity Persistence:** Each SONiC device keeps a static ZeroTier identity, ensuring a consistent Node ID across reboots or rebuilds.

---

## Directory Structure

```
/home/admin/sonic-wan/
├── enable-wan-in-sonic.sh
├── wan-containers.sh
├── pbr-setup.sh
├── logs/
│    ├── wireguard.log
│    └── zerotier.log
└── .secrets/
     ├── wireguard/
     │    └── wg0.conf
     └── zerotier/
          ├── identity.public
          └── identity.secret
```

---

## The Bake Process (Pre-Build Setup)

### Getting the SONiC Base Image

To begin, you’ll need a base SONiC Virtual Switch (VS) image.

You can download prebuilt SONiC VM images from the **unofficial SONiC build repository**:  
➡️ [https://sonic.software/](https://sonic.software/)

For this project, use the following build configuration:
- **Branch:** `master`  
- **Image:** `sonic-vs.img.gz`  
- **Build Type:** *Nightly / Latest* — ideal for proof-of-concept environments where frequent updates are acceptable.

After downloading, decompress the image:
```bash
gunzip sonic-vs.img.gz
```
This file (`sonic-vs.img`) will serve as the base image you boot under KVM, prepare with the WAN containers and scripts, and later convert to a Containerlab-compatible image using vrnetlab.

ToDo: Describe how to convert to qow2 format
ToDo: Show how to start the KVM
ToDo: Describe the vrnetlab process to create the containerlab SONiC-VM Container


1. Convert the `sonic-vs.img` file to qow2 format
2. Launch a clean SONiC VM
3. Clone the repo into `/home/admin/sonic-wan`
4. Add `.secrets` directory and required config files
5. Manually load the custom `zerotier:wan` image:
   ```bash
   docker load -i zerotier-wan.tar
   ```
6. Run the setup script:
   ```bash
   sudo ./enable-wan-in-sonic.sh
   ```

---

## Runtime Behavior

```
ip -br addr
wg0              UNKNOWN        172.27.66.101/24
zt0              UNKNOWN        10.147.20.146/24
```

Both tunnels appear on the SONiC host.  
`wg0` = Secure Web Access (default route)  
`zt0` = Site-to-site overlay (specific routes)

---

## Policy-Based Routing Logic

Implemented in `pbr-setup.sh`.  
- `table 100` → ZeroTier  
- `table 200` → WireGuard  
- VLAN source-based routing rules steer traffic correctly.
- Does **not** modify SONiC's `/etc/sonic/config_db.json`.

---

## Containerlab Integration

After baking, convert VM to container using `vrnetlab`:

```bash
./vrnetlab.sh --build --vm /path/to/sonic-vm.qcow2 --tag vrnetlab/sonic_secure_wan:latest
```

Then reference in Containerlab topology:

```yaml
core1:
  kind: sonic-vm
  image: vrnetlab/sonic_secure_wan:latest
```

---

## License

This project is released under [The Unlicense](https://unlicense.org/).

---

**Net-Innovate Solutions GmbH**  
*No Architecture — No Transformation.*
