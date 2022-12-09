#!/bin/bash
add-apt-repository ppa:greaterfire/trojan
apt update -y 
# Install nginx
apt install nginx -y
systemctl enable nginx
systemctl start nginx
sed -i "s/server_name _;/server_name $1.$2;/g" /etc/nginx/sites-available/default
nginx -t
sed -i 's/listen \[::\]:443 ssl ipv6only=on; # managed by Certbot//g' /etc/nginx/sites-available/default
sed -i 's/listen 443 ssl; # managed by Certbot//g' /etc/nginx/sites-available/default
systemctl restart nginx
systemctl status nginx

# Install camouflage website

apt install zip unzip -y
rm -rf master.zip
rm -rf sample-blog-master
wget https://github.com/arcdetri/sample-blog/archive/master.zip
unzip master.zip
cp -rf sample-blog-master/html/* /var/www/html/

# Install certificate
# Before this step, DNS record should be there in advance.
apt install certbot python3-certbot-nginx -y
certbot run -n --nginx --agree-tos -d "$1.$2" -m iecanfly@gmail.com --redirect
chmod -R +rx /etc/letsencrypt

# Install trojan
rm /etc/systemd/system/trojan.service
apt install trojan -y

# Create a SystemD service
rm /etc/systemd/system/trojan.service
tee -a /etc/systemd/system/trojan.service > /dev/null <<EOT
[Unit]
Description=trojan
Documentation=man:trojan(1) https://trojan-gfw.github.io/trojan/config https://trojan-gfw.github.io/trojan/
After=network.target network-online.target nss-lookup.target mysql.service mariadb.service mysqld.service

[Service]
Type=simple
StandardError=journal
User=nobody
AmbientCapabilities=CAP_NET_BIND_SERVICE
ExecStart=/usr/bin/trojan /etc/trojan/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=1s

[Install]
WantedBy=multi-user.target
EOT

# Configure trojan
rm /etc/trojan/config.json 
tee -a /etc/trojan/config.json > /dev/null <<EOT
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": 443,
    "remote_addr": "127.0.0.1",
    "remote_port": 80,
    "password": [
        "jQw2jjodg4ygzkzAeXUH"
    ],
    "log_level": 3,
    "ssl": {
        "cert": "/path/to/certificate.crt",
        "key": "/path/to/private.key",
        "key_password": "",
        "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384",
        "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
        "prefer_server_cipher": true,
        "alpn": [
            "http/1.1"
        ],
        "alpn_port_override": {
            "h2": 81
        },
        "reuse_session": true,
        "session_ticket": false,
        "session_timeout": 600,
        "plain_http_response": "",
        "curves": "",
        "dhparam": ""
    },
    "tcp": {
        "prefer_ipv4": false,
        "no_delay": true,
        "keep_alive": true,
        "reuse_port": false,
        "fast_open": false,
        "fast_open_qlen": 20
    },
    "mysql": {
        "enabled": false,
        "server_addr": "127.0.0.1",
        "server_port": 3306,
        "database": "trojan",
        "username": "trojan",
        "password": "trojan_Gideon",
        "key": "",
        "cert": "",
        "ca": ""
    }
}
EOT

sed -i "s/\/path\/to\/certificate.crt/\/etc\/letsencrypt\/live\/$1.$2\/fullchain.pem/g" /etc/trojan/config.json
sed -i "s/\/path\/to\/private.key/\/etc\/letsencrypt\/live\/$1.$2\/privkey.pem/g" /etc/trojan/config.json

# Open ports
ufw allow 443
ufw allow 80

tee -a /etc/sysctl.conf >> /dev/null <<EOT
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOT

sysctl -p

systemctl enable trojan
systemctl start trojan

lsof -i -P
