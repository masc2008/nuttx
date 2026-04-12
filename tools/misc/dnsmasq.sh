sudo ip tuntap add dev tap0 mode tap
sudo ip addr add 192.168.50.1/24 dev tap0
sudo ip link set tap0 up

dnsmasq --no-daemon --log-dhcp --log-queries \
    --interface=tap0 --bind-interfaces \
    --dhcp-authoritative \
    --dhcp-range=192.168.50.20,192.168.50.50,255.255.255.0 \
    --dhcp-option=option:router,192.168.50.1 \
    --dhcp-option=option:dns-server,1.1.1.1 \
    --dhcp-option=option:ntp-server,162.159.200.123
