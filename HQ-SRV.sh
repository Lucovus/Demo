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
read -p "Напишите IP интерфейса enp2s3 без маски который на ISP " ip_br_rtr
read -p "Напишите IP интерфейса enp2s2 без маски который на ISP " ip_hq_rtr
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
docker  IN   A    ${ip_br_rtr}
web     IN   A    ${ip_hq_rtr}

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

parted -s /dev/sdb mklabel msdos mkpart primary 1MiB 100% set 1 raid on
parted -s /dev/sdc mklabel msdos mkpart primary 1MiB 100% set 1 raid on

mdadm --create /dev/md0 --level=0 --raid-devices=2 /dev/sdb1 /dev/sdc1 --yes
mdadm --detail --scan >> /etc/mdadm.conf
mkfs.ext4 /dev/md0
mkdir /raid
cp /etc/fstab /etc/fstab.back
echo "/dev/md0 /raid ext4 defaults 0 0	" >> /etc/fstab
mount -av
df -T

apt-get update && apt-get install nfs-server nfs-utils -y
mkdir -p /raid/nfs
chmod 777 /raid/nfs
cp /etc/exports /etc/exports.back
echo "/raid/nfs 192.168.200.0/27(rw,no_subtree_check,no_root_squash)" >> /etc/exports
systemctl enable --now nfs-server

mount -o loop /dev/sr0 /mnt/ -v
apt-get install lamp-server -y
cp /mnt/web/index.php /var/www/html 
cp /mnt/web/logo.png /var/www/html

systemctl enable --now mariadb

mariadb -e "CREATE DATABASE webdb;"
mariadb -e "
CREATE USER 'web'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'web'@'localhost';
"

mariadb webdb < /mnt/web/dump.sql
read -p "Какой пользователь прописан в задании? " webUser
read -p "Какой пароль пользователя прописан в задании? " passUser
sed -i "s/^\$username = .*/\$username = \"${webUser}\";/" /var/www/html/index.php
sed -i "s/^\$password = .*/\$password = \"${passUser}\";/" /var/www/html/index.php
systemctl enable --now httpd2.service
exec bash
