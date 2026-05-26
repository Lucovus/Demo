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
    int_type="enp2s1"
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

apt-get update && apt-get install iptables -y
echo ""
echo -e "\e[32mОбновлён репозиторий. установлен iptables\e[0m"
echo ""
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
sysctl -p

if ip link show $int_type up &>/dev/null; then
  iptables -t nat -A POSTROUTING -o $int_type -j MASQUERADE
  /etc/init.d/iptables save
  systemctl enable --now iptables
else
  echo ""
  echo -e "\e[31mИнтерфейс $int_type не найден. ты точно выбрал proxmox?"
  echo ""
fi
if [[ $Hypervisor == 2 ]]; then
  read -p "какой ip в сторону HQ-RTR? пиши без пробелов. пример: 172.25.1.1 " ip_enp2s2
  read -p "какой ip в сторону BQ-RTR? пиши без пробелов. пример: 172.26.1.1 " ip_enp2s3
  mkdir /etc/net/ifaces/enp2s2
  mkdir /etc/net/ifaces/enp2s3
  echo -e "BOOTPROTO=static\nTYPE=eth" > /etc/net/ifaces/enp2s2/options
  echo -e "BOOTPROTO=static\nTYPE=eth" > /etc/net/ifaces/enp2s3/options
  echo "$ip_enp2s2" > /etc/net/ifaces/enp2s2/ipv4address
  echo "$ip_enp2s3" > /etc/net/ifaces/enp2s3/ipv4address
fi
apt-get update && apt-get install nginx -y
cat << "EOF" > /etc/nginx/sites-available.d/r-proxy.conf
server {
    listen 80;
    server_name web.au-team.irpo;

    location / {
        proxy_pass http://${ip_enp2s2}:8080;
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
        proxy_pass http://${ip_enp2s3}:8080;
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
apt-get update && apt-get install apache2-htpasswd -y
read -p "Какой пользователь указан в задани для Apache2? Напиши без пробелов " user_apache
htpasswd -c /etc/nginx/.htpasswd $user_apache
systemctl restart network
exec bash
