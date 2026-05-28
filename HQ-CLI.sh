#!/bin/bash
say() {
        echo "$1" | iconv -f utf-8 -t cp1251 2>/dev/null || echo "$1"
}
hostnamectl hostname hq-cli.au-team.irpo

apt-get update && apt-get install yandex-browser-stable -y 

mkdir /mnt/nfs
chmod -R 777 /mnt/nfs
showmount -e hq-srv
cp /etc/fstab /etc/fstab.back
echo "192.168.100.2:/raid/nfs /mnt/nfs nfs rw,soft,_netdev 0 0	" >> /etc/fstab
mount -av
df -T
