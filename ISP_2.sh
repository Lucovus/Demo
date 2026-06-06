#!/bin/bash
say() {
        echo "$1" | iconv -f utf-8 -t cp1251 2>/dev/null || echo "$1"
}
echo -e "1) VMware\n2) Proxmox"
read -p "Выберите вариант: (1 или 2)" Hypervisor
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

if ip link show $int_type up &>/dev/null; then
  iptables -t nat -A POSTROUTING -o $int_type -j MASQUERADE
  /etc/init.d/iptables save
  systemctl enable --now iptables
else
  echo ""
  echo -e "\e[31mИнтерфейс $int_type не найден. ты точно выбрал proxmox?"
  echo ""
fi

apt-get update && apt-get install nginx -y
cat << EOF > /etc/nginx/sites-available.d/r-proxy.conf
server {
    listen 80;
    server_name web.au-team.irpo;

    location / {
        proxy_pass http://172.16.70.1:8084;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        auth_basic "Restricted Access";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}

server {
    listen 80;
    server_name docker.au-team.irpo;

    location / {
        proxy_pass http://172.16.80.1:8084;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
echo -e "\e[32mNginx файл конфига готов\e[0m"
ln -s /etc/nginx/sites-available.d/r-proxy.conf /etc/nginx/sites-enabled.d/
systemctl enable --now nginx
apt-get update && apt-get install apache2-htpasswd -y
htpasswd -c /etc/nginx/.htpasswd web4c
echo "ПарОль для юзера веба"
systemctl restart network
exec bash
