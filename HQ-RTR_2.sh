#!/bin/bash
apt-get update && apt-get install iptables -y
systemctl disable --now nftables
iptables -t nat -A POSTROUTING -o enp7s1 -j MASQUERADE
iptables -t nat -A PREROUTING -i enp7s1 -p tcp --dport 2014 -j DNAT --to-destination 192.168.100.2
iptables -t nat -A PREROUTING -i enp7s1 -p tcp --dport 8084 -j DNAT --to-destination 192.168.100.2:80

/etc/init.d/iptables save
systemctl enable --now iptables
