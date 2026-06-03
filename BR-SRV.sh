#!/bin/bash
say() {
        echo "$1" | iconv -f utf-8 -t cp1251 2>/dev/null || echo "$1"
}
hostnamectl hostname br-srv.au-team.irpo
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

echo -e "\e[32Установка SambaAD \e["
apt-get update && apt-get install -y task-samba-dc
rm -f /etc/samba/smb.conf
rm -rf {/var/lib/samba, /var/cache/samba}
mkdir -p /var/lib/samba/sysvol
samba-tool domain provision

mv /etc/krb5.conf /etc/krb5.conf.back 
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf 

sed -i 's/nameserver 8.8.8.8/nameserver 127.0.0.1/' /etc/net/ifaces/enp7s1/resolv.conf; systemctl restart network; cat /etc/resolv.conf

echo -e "\e[33Внимание! в DNS backend укажи IP HQ-SRV !!!\e["

samba-tool dns add br-srv.au-team.irpo au-team.irpo hq-srv A 192.168.1.10 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo hq-rtr A 192.168.1.1 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo br-rtr A 192.168.3.1 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo web.au-team.irpo A 172.16.1.1 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo docker.au-team.irpo A 172.16.2.1 -U Administrator

for i in {1..5}; do samba-tool user add hquser$i P@ssw0rd; done
for i in {1..5}; do samba-tool group addmembers hq hquser$i; done
apt-get install ansible sshpass -y
sed -i '/^\[defaults\]/a host_key_checking = False\ninterpreter_python=auto_silent'

systemctl enable --now samba 
systemctl restart sshd
exec bash
