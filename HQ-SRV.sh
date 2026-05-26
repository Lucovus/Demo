#!/bin/bash

hostnamectl hostname hq-srv.au-team.irpo
apt-get update && apt-get install sudo

useradd -u 2026 sshuser
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser
