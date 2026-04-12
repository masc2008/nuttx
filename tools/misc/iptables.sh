sudo iptables -t nat -A POSTROUTING -s 192.168.50.0/24 -o wlp0s20f3 -j MASQUERADE
sudo iptables -A FORWARD -i tap0 -o wlp0s20f3 -j ACCEPT
sudo iptables -A FORWARD -i wlp0s20f3 -o tap0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
