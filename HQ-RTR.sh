#!bin/bash
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
hostnamectl hostname hq-rtr.au-team.irpo

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
if [[ $Hypervisor == 2 ]]; then
  mkdir -p /etc/net/ifaces/{enp2s2,vlan{100,200,999}}
  touch /etc/net/ifaces/enp2s2/options
  echo "TYPE=eth" > /etc/net/ifaces/enp2s2/options
  echo $'100\n200\n999' | xargs -i bash -c 'echo -e "TYPE=vlan\nHOST=enp2s2\nVID={}" > /etc/net/ifaces/vlan{}/options'
else
  mkdir -p /etc/net/ifaces/{ens37,vlan{100,200,999}}
  touch /etc/net/ifaces/ens37/options
  echo "TYPE=eth" > /etc/net/ifaces/ens37/options
  echo $'100\n200\n999' | xargs -i bash -c 'echo -e "TYPE=vlan\nHOST=ens37\nVID={}" > /etc/net/ifaces/vlan{}/options'
fi
echo ""
read -p "Какой IP адресс и МАСКА для vlan100 ПО ЗАДАНИЮ? пиши без пробелов пример: 192.168.100.1/27" ip_vlan100
read -p "Какой IP адресс и МАСКА для vlan200 ПО ЗАДАНИЮ? пиши без пробелов пример: 192.168.200.1/28" ip_vlan200
read -p "Какой IP адресс и МАСКА для vlan999 ПО ЗАДАНИЮ? пиши без пробелов пример: 192.168.99.1/29" ip_vlan999
echo ""
echo "$ip_vlan100" > /etc/net/ifaces/vlan100/ipv4address
echo "$ip_vlan200" > /etc/net/ifaces/vlan200/ipv4address
echo "$ip_vlan100" > /etc/net/ifaces/vlan999/ipv4address

iptables -t nat -A PREROUTING -i $int_type -p tcp --dport 2026 -j DNAT --to-destination ${ip_vlan100%/*}
iptables -t nat -A PREROUTING -i $int_type -p tcp --dport 8080 -j DNAT --to-destination ${ip_vlan100%/*}:80

apt-get update && apt-get install sudo -y
useradd net_admin
echo "net_admin:P@ssw0rd" | chpasswd
usermod -aG wheel net_admin
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/net_admin

mkdir -p /etc/net/ifaces/gre1
touch /etc/net/ifaces/gre1/options
touch /etc/net/ifaces/gre1/ipv4address
echo "10.10.10.1/30" > /etc/net/ifaces/gre1/ipv4address

read -p "Напишите IP HQ-RTR который смотрет на верх (В сторону ISP) " ip_hq_rtrr
read -p "Напишите IP BR-RTR который смотрет на верх (В сторону ISP) " ip_br_rtrr
cat << EOF > /etc/net/ifaces/gre1/options
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=${ip_hq_rtrr}
TUNREMOTE=${ip_br_rtrr}
TUNOPTIONS='ttl 64'
EOF
systemctl restart network

apt-get update && apt-get install frr -y
cat <<'EOF' > /etc/frr/frr.conf
interface gre
 no ip ospf passive
exit
!
interface gre1
 ip ospf area 0
 ip ospf authentication
 ip ospf authentication-key P@ssw0rd
 no ip ospf passive
exit
!
interface vlan100
 ip ospf area 0
exit
!
interface vlan200
 ip ospf area 0
exit
!
interface vlan999
 ip ospf area 0
exit
!
router ospf
 passive-interface default
exit

EOF

systemctl restart network
systemctl enable -now frr

apt-get update && apt-get install dnsmasq -y
sed -i 's/AUTO_LOCAL_RESOLVER=yes/AUTO_LOCAL_RESOLVER=no/' /etc/sysconfig/dnsmasq ; grep AUTO_LOCAL_RESOLVER /etc/sysconfig/dnsmasq

cat <<'EOF' > /etc/dnsmasq.conf
port=0
interface=vlan200
listen-address=192.168.200.1
dhcp-authoritative
dhcp-range=interface:vlan200,192.168.200.2,192.168.200.2,255.255.255.240,6h
dhcp-option=3,192.168.200.1
dhcp-option=6,192.168.100.2
leasefile-ro
EOF
systemctl enable --now dnsmasq

exec bash
