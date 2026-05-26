#!/bin/bash
say() {
        echo "$1" | iconv -f utf-8 -t cp1251 2>/dev/null || echo "$1"
}

hostnamectl hostname hq-srv.au-team.irpo
apt-get update && apt-get install sudo

read -p "какой индентификатор у пользователя sshuser по заданию? Без пробелов " id_sshuser
useradd -u $id_sshuser sshuser
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser

echo "Authorized access only" > /etc/openssh/banner
read -p "какой порт у ssh по заданию? Без пробелов " port_ssh
read -p "Сколько попыток авторизации по заданию? Без пробелов только цифру " Max_auth
echo -e "Port ${port_ssh}\nMaxAuthTries ${Max_auth}\nAllowUsers sshuser\nBanner /etc/openssh/banner\n" >> /etc/openssh/sshd_config
systemctl restart sshd

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
read -p "Напишите IP интерфейса enp2s1 без маски на HQ-RTR " ip_br-rtr
cat <<'EOF' > /etc/bind/zone/au-team.irpo
$TTL  1D
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
br-rtr  IN   A    ${ip_br-rtr}
br-srv  IN   A    192.168.1.2
docker  IN   A    172.16.1.1
web     IN   A    172.16.2.1

EOF

exec bash
