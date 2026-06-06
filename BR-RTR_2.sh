#!/bin/bash

systemctl disable --now nftables
apt-get update && apt-get install iptables -y
iptables -t nat -A PREROUTING -i enp7s1 -p tcp -m multiport --dports 8084,2014 -j DNAT --to-destination 192.168.1.1
echo ""
echo -e "\e[32mОбновлён репозиторий. установлен iptables\e[0m"
echo ""
systemctl restart network

iptables -t nat -A POSTROUTING -o enp7s1 -j MASQUERADE
/etc/init.d/iptables save
systemctl enable --now iptables
