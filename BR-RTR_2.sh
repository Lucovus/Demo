
iptables -t nat -A PREROUTING -i $int_type -p tcp -m multiport --dports 8084,2014 -j DNAT --to-destination 192.168.1.1
