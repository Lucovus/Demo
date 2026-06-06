#!/bin/bash
apt-get update && apt-get install -y task-samba-dc
rm -f /etc/samba/smb.conf
rm -rf {/var/lib/samba, /var/cache/samba}
mkdir -p /var/lib/samba/sysvol
echo -e "\e[33Внимание! в DNS forwardes укажи IP HQ-SRV !!!\e["
mv /etc/krb5.conf /etc/krb5.conf.back 
cp /var/lib/samba/private/krb5.conf/etc/krb5.conf 
echo -e "\e[33Внимание! Укажите пароль админа P@ssw0rd !!!\e["
samba-tool domain provision

sed -i 's/nameserver 8.8.8.8/nameserver 127.0.0.1/' /etc/net/ifaces/enp7s1/resolv.conf; systemctl restart network; cat /etc/resolv.conf

samba-tool dns add br-srv.au-team.irpo au-team.irpo hq-srv A 192.168.100.2 -U Administrator --password P@ssw0rd
samba-tool dns add br-srv.au-team.irpo au-team.irpo hq-rtr A 192.168.100.1 -U Administrator --password P@ssw0rd
samba-tool dns add br-srv.au-team.irpo au-team.irpo br-rtr A 192.168.1.2 -U Administrator --password P@ssw0rd
samba-tool dns add br-srv.au-team.irpo au-team.irpo web.au-team.irpo A 172.16.70.1 -U Administrator --password P@ssw0rd
samba-tool dns add br-srv.au-team.irpo au-team.irpo docker.au-team.irpo A 172.16.80.1 -U Administrator --password P@ssw0rd

samba-tool group add hq
for i in {1..5}; do
    samba-tool user add "hquser$i" P@ssw0rd
done

for i in {1..5}; do
    samba-tool group addmembers "hq" "hquser$i" --object-types=user
done

apt-get install ansible sshpass -y
sed -i '/^\[defaults\]/a host_key_checking = False\ninterpreter_python=auto_silent'

cat <<EOF >/etc/ansible/hosts
HQ-SRV ansible_user=user ansible_password=resu ansible_port=2014
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
      MARIADB_DATABASE: testdb4
      MARIADB_USER: test4c
      MARIADB_PASSWORD: P@ssw0rd
      MARIADB_ROOT_PASSWORD: P@ssw0rd
    volumes:
      - db_data:/var/lib/mysql
      
  app:
    container_name: testapp
    image: site:latest
    restart: always
    ports: 
      - "8084:8000"
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
