# Start by building the application.
FROM docker.io/golang:1.21 as build
WORKDIR /usr/src/wireproxy
COPY . .
RUN make

# Now copy it into our base image.
FROM debian:bullseye-slim
RUN apt-get update && apt-get install -y iproute2 && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY --from=build /usr/src/wireproxy/wireproxy /usr/bin/wireproxy

# Create a script to run the network setup commands before starting wireproxy
RUN echo '#!/bin/bash\n\
ip tunnel add he-ipv6 mode sit remote "${SERVER_IPV4}" local $(ip addr show eth0 | grep "inet " | awk "{print \$2}" | cut -d"/" -f1) ttl 255\n\
ip link set he-ipv6 up\n\
ip addr add "${CLIENT_IPV6}" dev he-ipv6\n\
ip route add ::/0 dev he-ipv6\n\
ip -f inet6 addr\n\
exec /usr/bin/wireproxy --config /etc/wireproxy/config\n' > /entrypoint.sh

RUN chmod +x /entrypoint.sh

VOLUME ["/etc/wireproxy"]
ENTRYPOINT ["/entrypoint.sh"]

LABEL org.opencontainers.image.title="wireproxy"
LABEL org.opencontainers.image.description="Wireguard client that exposes itself as a socks5 proxy"
LABEL org.opencontainers.image.licenses="ISC"
