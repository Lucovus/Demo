#!/bin/bash
say() {
        echo "$1" | iconv -f utf-8 -t cp1251 2>/dev/null || echo "$1"
}
hostnamectl hostname br-srv.au-team.irpo
apt-get update && apt-get install sudo 
read -p "какой индентификатор у пользователя sshuser по заданию? Без пробелов " id_sshuser
useradd -u $id_sshuser sshuser
echo "sshuser:P@ssw0rd" | chpasswd
usermod -aG wheel sshuser
echo "WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser

echo "Authorized access only" > /etc/openssh/banner
read -p "какой порт у ssh по заданию? Без пробелов " port_ssh
read -p "Сколько попыток авторизации по заданию? Без пробелов только цифру " Max_auth
echo -e "Port ${port_ssh}\nMaxAuthTries ${Max_auth}\nAllowUsers sshuser\nBanner /etc/openssh/banner\n" >> /etc/openssh/sshd_config


apt-get update && apt-get install -y task-samba-dc
rm -f /etc/samba/smb.conf
rm -rf {/var/lib/samba, /var/cache/samba}
mkdir -p /var/lib/samba/sysvol
echo -e "\e[33Внимание! в DNS forwardes укажи IP HQ-SRV !!!\e["
mv /etc/krb5.conf /etc/krb5.conf.back 
cp /var/lib/samba/private/krb5.conf/etc/krb5.conf 
samba-tool domain provision

sed -i 's/nameserver 8.8.8.8/nameserver 127.0.0.1/' /etc/net/ifaces/enp7s1/resolv.conf; systemctl restart network; cat /etc/resolv.conf

read -p "Напишите IP интерфейса enp2s3 без маски который на ISP " ip_br_rtr
read -p "Напишите IP интерфейса enp2s2 без маски который на ISP " ip_hq_rtr

samba-tool dns add br-srv.au-team.irpo au-team.irpo hq-srv A 192.168.100.2 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo hq-rtr A 192.168.100.1 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo br-rtr A 192.168.1.2 -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo web.au-team.irpo A ${ip_hq_rtr} -U Administrator
samba-tool dns add br-srv.au-team.irpo au-team.irpo docker.au-team.irpo A ${ip_br_rtr} -U Administrator

for i in {1..5}; do samba-tool user add hquser$i P@ssw0rd; done
for i in {1..5}; do samba-tool group addmembers hq hquser$i; done
apt-get install ansible sshpass -y
sed -i '/^\[defaults\]/a host_key_checking = False\ninterpreter_python=auto_silent'

cat <<EOF >/etc/ansible/hosts
HQ-SRV ansible_user=user ansible_password=resu ansible_port=${port_ssh}
HQ-RTR ansible_user=net_admin ansible_password=P@ssw0rd
BR-RTR ansible_user=net_admin ansible_password=P@ssw0rd 
HQ-CLI ansible_user=user ansible_password=resu
EOF

apt-get install docker-engine docker-compose-v2 -y
systemctl enable --now docker.service
mount -o loop /dev/sr0 /mnt/ -v

docker load < /mnt/docker/site_latest.tar
docker load < /mnt/docker/mariadb_latest.tar
touch docker-compose.yml

cat << EOF > docker-compose.yml
services:
  database:
    container_name: db
    image: mariadb:latest
    restart: always
    ports: 
      - "3306:3306"
    environment:
      MARIADB_DATABASE: testdb
      MARIADB_USER: test
      MARIADB_PASSWORD: P@ssw0rd
      MARIADB_ROOT_PASSWORD: P@ssw0rd
    volumes:
      - db_data:/var/lib/mysql
      
  app:
    container_name: testapp
    image: site:latest
    restart: always
    ports: 
      - "8080:8000"
    environment: 
      DB_HOST: database
      DB_PORT: 3306
      DB_NAME: testdb
      DB_USER: test
      DB_PASS: P@ssw0rd
      DB_TYPE: maria
    depends_on: 
      - database
volumes:
  db_data:
EOF

docker compose config
docker compose up -d 
docker ps

systemctl enable --now samba 
systemctl restart sshd
exec bash
