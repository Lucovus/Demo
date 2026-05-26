#!/bin/bash

hostnamectl hostname hq-srv.au-team.irpo
apt-get update && apt-get install sudo

read -p "какой индентификатор у пользователя sshuser по заданию? Без пробелов " id_sshuser
useradd -u $id_sshuser sshuser
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser
