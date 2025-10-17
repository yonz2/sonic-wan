# 1. Create the necessary VLANs
sudo config vlan add 10
sudo config vlan add 30
sudo config vlan add 1001

# 2. Delete the default L3 interface definitions
sudo config interface del Ethernet0
sudo config interface del Ethernet12
sudo config interface del Ethernet24
sudo config interface del Ethernet28

# 3. Bring the interfaces up administratively
sudo config interface startup Ethernet0
sudo config interface startup Ethernet12
sudo config interface startup Ethernet24
sudo config interface startup Ethernet28

# 4. Disable the Per-VLAN Spanning Tree Protocol
sudo config spanning-tree disable pvst

# 5. Configure the uplink to the router (Ethernet0) as a trunk port
sudo config vlan member add 10 Ethernet0
sudo config vlan member add 30 Ethernet0
sudo config vlan member add 1001 Ethernet0

# 6. Configure the access ports for the clients
sudo config vlan member add -u 10 Ethernet12
sudo config vlan member add -u 30 Ethernet24
sudo config vlan member add -u 30 Ethernet28

# 7. Save the configuration persistently
sudo config save -y
