#!/bin/bash
hostnamectl hostname br-srv.au-team.irpo
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
exec bash
