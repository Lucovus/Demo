
read -p "какой ip в сторону HQ-RTR? пиши без пробелов. пример: 172.25.1.1/30 " ip_enp2s2
read -p "какой ip в сторону BQ-RTR? пиши без пробелов. пример: 172.26.1.1/30 " ip_enp2s3

cat << EOF > /etc/nginx/sites-available.d/r-proxy.conf
server {
    listen 80;
    server_name web.au-team.irpo;

    location / {
        proxy_pass http://${ip_enp2s2%/*}:8080;
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
        proxy_pass http://${ip_enp2s3%/*}:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
