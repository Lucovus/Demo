#!/bin/bash

echo "Выберете гипервизор. Proxmox или WMware (пиши ТОЛЬКО 1 или 2)"
read -p "2) - proxmox 1) - WMware " Hypervisor
case $Hypervisor in
  1)
    int_type="ens33"
    ;;
  2)
    int_type="enp7s1"
    ;;
  *)
    echo "Неправльно. напиши 1 или 2"
    exit 1 
    ;;
esac
echo ""
echo -e "\e[32mИспользуется $int_type\e[0m"
echo ""
hostnamectl hostname isp.au-team.irpo

apt-get update $$ apt-get install iptables -y
echo ""
echo -e "\e[32mОбновлён репозиторий. установлен iptables\e[0m"
echo ""
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
sysctl -p
systemctl restart network

if ip link show $int_type up &>/dev/null; then
  iptables -t nat -A POSTROUTING -o $int_type -j MASQUERADE
  /etc/init.d/iptables save
  systemctl enable --now iptables
else
  echo ""
  echo -e "\e[31mИнтерфейс $int_type не найден. ты точно выбрал proxmox?"
  echo ""
fi

apt-get install nginx -y
cat << "EOF" > /etc/nginx/sites-available.d/r-proxy.conf
server {
    listen 80;
    server_name web.au-team.irpo;

    location / {
        proxy_pass http://172.16.1.10:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}

server {
    listen 80;
    server_name docker.au-team.irpo;

    location / {
        proxy_pass http://172.16.2.10:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
echo -e "\e[32mNginx файл конфига готов\e[0m"
ln -s /etc/nginx/sites-available.d/r-proxy.conf /etc/nginx/sites-enabled.d/
systemctl enable --now nginx
apt-get install apache2-htpasswd -y
read -p "Какой пароль указан в задани для Apache2? Напиши без пробелов" pass_apache
htpasswd -c /etc/nginx/.htpasswd $pass_apache

exec bash
