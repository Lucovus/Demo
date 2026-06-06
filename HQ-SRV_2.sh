#!/bin/bash
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
CREATE USER 'web4c'@'localhost' IDENTIFIED BY 'P@ssw0rd';
GRANT ALL PRIVILEGES ON webdb.* TO 'web4c'@'localhost';
"

mariadb webdb < /mnt/web/dump.sql

sed -i "s/^\$username = .*/\$username = \"web4c\";/" /var/www/html/index.php
sed -i "s/^\$password = .*/\$password = \"P@ssw0rd\";/" /var/www/html/index.php
systemctl enable --now httpd2.service
exec bash
