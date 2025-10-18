#!/bin/bash
#
#
docker network create -d macvlan \
  --subnet=192.168.178.0/24 \
  --gateway=192.168.178.1 \
  -o parent=br0 \
  host-net

docker run -it --rm \
  --name sonic-test-client \
  --net=host-net \
  --cap-add=NET_ADMIN \
  linux-client:full /bin/bash