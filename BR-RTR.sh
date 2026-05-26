#!bin/bash
echo "Выберете гипервизор. Proxmox или WMware (пиши ТОЛЬКО 1 или 2)"
read -p "2) - proxmox 1) - WMware " Hypervisor
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
hostnamectl hostname br-rtr.au-team.irpo

apt-get update && apt-get install iptables -y
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
read -p "Какой айпи адресс в сторону BR-SRV? Посмотри задание. Пиши без пробелов. Рекмоендуется 192.168.1.1/24 " ip_srv
iptables -t nat -A PREROUTING -i $int_type -p tcp -m multiport --dports 8080,2026 -j DNAT --to-destination $ip_srv

mkdir -p /etc/net/ifaces/gre1
touch /etc/net/ifaces/gre1/options
touch /etc/net/ifaces/gre1/ipv4address
echo "10.10.10.2/30" > /etc/net/ifaces/gre1/ipv4address

cat << EOF > /etc/net/ifaces/gre1/options
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.2.2
TUNREMOTE=172.16.1.2
TUNOPTIONS='ttl 64'
EOF
systemctl restart network

apt-get update && apt-get install sudo -y
useradd net_admin
echo "net_admin:P@ssw0rd" | chpasswd
usermod -aG wheel net_admin
touch /etc/sudoers.d/net_admin
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/net_admin

apt-get update && apt-get install frr -y
sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons ; grep ospf /etc/frr/daemons
cat <<'EOF' > /etc/frr/frr.conf

interface gre1
 ip ospf area 0
 ip ospf authentication
 ip ospf authentication-key P@ssw0rd
 no ip ospf passive
exit
!
interface enp2s2
 ip ospf area 0
exit
!
router ospf
 passive-interface default
exit
EOF
systemctl restart network
systemctl enable --now frr
systemctl enable --now sshd
exec bash
