sudo ip addr add fc00::1/64 dev tap0

sudo sysctl -w net.ipv6.conf.all.forwarding=1

sudo ip6tables -A FORWARD -i tap0 -o enxa2ee1addced1 -j ACCEPT
sudo ip6tables -A FORWARD -i enxa2ee1addced1 -o tap0 -m state --state ESTABLISHED,RELATED -j ACCEPT

sudo ip6tables -t nat -A POSTROUTING -s fc00::/64 -o enxa2ee1addced1 -j MASQUERADE


#ping6 2606:4700:4700::1111
#addroute default fc00::1 eth0
#
#ifconfig eth0 inet6 add fc00::2/64
#addroute default fc00::1 eth0
#ping6 2606:4700:4700::1111

# sudo ip6tables -L FORWARD -n -v
#sysctl net.ipv6.conf.all.forwardingrwarding
# ping6 -c 3 2606:4700:4700::1111
