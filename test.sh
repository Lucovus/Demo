apt-get update && apt-get install bind bind-utils -y
cat <<'EOF' > /etc/bind/options.conf
logging { };
options {
 listen-on { any; };
 forwarders { 77.88.8.7; 77.88.8.3; };
 recursion yes;
 allow-recursion { any; };
 allow-query { any; };
 dnssec-validation no;
 
 directory "/etc/bind/zone";
 dump-file "/var/run/named/named_dump.db";
 statistics-file "/var/run/named/named.stats";
 recursing-file "/var/run/named/named.recursing"; 
 secroots-file "/var/run/named/named.scroots";
 pid-file none;
};
zone "au-team.irpo" {
 type master;
 file "au-team.irpo";
};
zone "168.192.in-addr.arpa" {
 type master;
 file "168.192.in-addr.arpa";
};
EOF
read -p "Напишите IP интерфейса enp2s1 без маски который на BR-RTR " ip_br_rtr
read -p "Напишите IP интерфейса enp2s1 без маски который на HQ-RTR " ip_hq_rtr
cat <<EOF > /etc/bind/zone/au-team.irpo
\$TTL  1D
@    IN   SOA   au-team.irpo. root.au-team.irpo. (
                2025020600 ; serial
                12H        ; refresh
                1H         ; retry
                1W         ; expire
                1H         ; ncache
            )
@       IN  NS    hq-srv.au-team.irpo.
hq-rtr  IN   A    192.168.100.1
hq-srv  IN   A    192.168.100.2
hq-cli  IN   A    192.168.200.2
br-rtr  IN   A    192.168.1.1
br-srv  IN   A    192.168.1.2
docker  IN   A    ${ip_hq_rtr}
web     IN   A    ${ip_br_rtr}

EOF

cat <<'EOF' > /etc/bind/zone/168.192.in-addr.arpa
$TTL  1D
@    IN   SOA   au-team.irpo. root.au-team.irpo. (
                2025020600 ; serial
                12H        ; refresh
                1H         ; retry
                1W         ; expire
                1H         ; ncache
            )
      IN   NS    au-team.irpo.
1.100 IN   PTR   hq-rtr.au-team.irpo.
2.100 IN   PTR   hq-srv.au-team.irpo.
2.200 IN   PTR   hq-cli.au-team.irpo.
EOF

chown :named /etc/bind/zone/au-team.irpo /etc/bind/zone/168.192.in-addr.arpa
systemctl enable --now bind
service network restart
