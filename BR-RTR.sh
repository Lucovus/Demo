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

mkdir -p /etc/net/ifaces/gre1
touch /etc/net/ifaces/gre1/options
touch /etc/net/ifaces/gre1/ipv4address
echo "10.10.10.2/30" > /etc/net/ifaces/gre1/ipv4address
systemctl restart network

useradd net_admin
echo "net_admin:P@ssw0rd" | chpasswd
usermod -aG wheel net_admin
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
interface enp7s2
 ip ospf area 0
exit
!
router ospf
 passive-interface default
exit
EOF
systemctl restart network
