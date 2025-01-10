#!/bin/bash

USER_HOME=$(eval echo ~$USER)

mkdir -p "$USER_HOME/docker-trudesk"
# Write nginx.conf using heredoc
cat << 'EOF' > "$USER_HOME/docker-trudesk/nginx.conf"
events {}

http {
    server {
        listen 80;
        server_name _; # Menggunakan IP atau domain server

        location / {
            proxy_pass http://trudesk:8118; # Alamat aplikasi yang akan di-reverse proxy
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
}
EOF

# Set appropriate permissions
chmod 644 "$USER_HOME/docker-trudesk/nginx.conf"

# make sure these directories exist and are writable by the user running the script
mkdir -p /data/db
mkdir -p /data/configdb
mkdir -p /data/trudesk/uploads
mkdir -p /data/trudesk/plugins
mkdir -p /data/trudesk/backups

docker run --name mongodb \
  -v /data/db:/data/db \
  -v /data/configdb:/data/configdb \
  -p 27017:27017 \
  -e MONGO_INITDB_ROOT_USERNAME=root \
  -e MONGO_INITDB_ROOT_PASSWORD=rumah \
  -d mongo:4.0-xenial

docker run -d --name mongoex --link mongodb:mongodb \
  -p 8081:8081 \
  -e ME_CONFIG_OPTIONS_EDITORTHEME=ambiance \
  -e ME_CONFIG_MONGODB_SERVER=mongodb \
  -e ME_CONFIG_BASICAUTH_USERNAME=root \
  -e ME_CONFIG_BASICAUTH_PASSWORD=rumah \
  -e ME_CONFIG_MONGODB_ADMINUSERNAME=root \
  -e ME_CONFIG_MONGODB_ADMINPASSWORD=rumah \
  mongo-express:latest

docker run --name trudesk \
  -v /data/trudesk/uploads:/usr/src/trudesk/public/uploads \
  -v /data/trudesk/plugins:/usr/src/trudesk/plugins \
  -v /data/trudesk/backups:/usr/src/trudesk/backups \
  -e NODE_ENV=production \
  -e TRUDESK_DOCKER=true \
  -e TD_MONGODB_URI="mongodb://root:rumah@mongodb:27017/trudesk?authSource=admin" \
  -p 8118 \
  -d polonel/trudesk:1

docker run -d --name nginx --link trudesk:trudesk \
    -p 80:80 \
    -v "/home/${USER_HOME}/docker-trudesk/nginx.conf:/etc/nginx/nginx.conf:ro" \
    nginx:stable-perl
