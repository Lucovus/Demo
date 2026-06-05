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
  mkdir /etc/net/ifaces/enp2s2
  mkdir /etc/net/ifaces/enp2s3
  echo -e "BOOTPROTO=static\nTYPE=eth" > /etc/net/ifaces/enp7s2/options
  echo -e "BOOTPROTO=static\nTYPE=eth" > /etc/net/ifaces/enp7s3/options
  echo "172.16.70.1" > /etc/net/ifaces/enp2s2/ipv4address
  echo "172.16.80.1" > /etc/net/ifaces/enp2s3/ipv4address
fi

systemctl restart network
exec bash
