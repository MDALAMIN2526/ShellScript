#!/bin/bash

# Overview: This script sets up a LEMP stack and installs Nextcloud.

# Update Packages
sudo apt update -y
sudo apt upgrade -y

# Install Nginx, MariaDB, and PHP
sudo apt install nginx mariadb-server php-fpm php-mysql php-xml php-mbstring php-intl php-zip php-gd php-curl php-bcmath php-gmp -y
sudo apt-get install imagemagick php-imagick -y

# Update PHP Extensions and memory_limit in php.ini
php_ini_path=$(php -i | grep "Loaded Configuration File" | cut -d' ' -f5)
enable_extension() {
    if ! grep -q "$1" "$php_ini_path"; then
        sudo sed -i "s/;$1/$1/g" "$php_ini_path"
    fi
}
enable_extension "extension=bcmath"
enable_extension "extension=imagick"
enable_extension "extension=gmp"
sudo sed -i 's/memory_limit = .*/memory_limit = 1024M/g' "$php_ini_path"

# Secure MariaDB Installation (manually set root password)
sudo mysql_secure_installation

# Create MariaDB Database
sudo mysql <<EOF
CREATE DATABASE nextcloud;
CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY 'NextCloud@2030';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextclouduser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
EOF

# Download and Extract Nextcloud
cd /var/www/
sudo wget https://download.nextcloud.com/server/releases/latest.tar.bz2
sudo tar -xjvf latest.tar.bz2
sudo rm -r latest.tar.bz2

# Set Permissions
sudo chown -R www-data:www-data /var/www/nextcloud 

# Get Server Name from User
read -p "Enter the server name or domain (e.g., yourdomain.com): " server_name

# Validate and set default server name if user input is empty
if [ -z "$server_name" ]; then
    server_name="127.0.0.1"
fi

# Configure Nginx Server Block
sudo tee /etc/nginx/sites-available/nextcloud > /dev/null <<EOF
server {
    listen 80;
    server_name $server_name;

    root /var/www/nextcloud;

    # Add this rewrite rule to redirect HTTP to HTTPS
    if ($host != $server_name) {
        rewrite ^ https://$server_name$request_uri permanent;
    }

    location / {
        index index.php;
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }
}

server {
    listen 443 ssl http2;
    server_name $server_name;

    root /var/www/nextcloud;

    ssl_certificate /etc/letsencrypt/live/$server_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$server_name/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'TLS_AES_128_GCM_SHA256:TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384';

    # Other SSL settings if needed

    location / {
        index index.php;
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
    }
}
EOF

# Enable the Nginx server block
sudo ln -s /etc/nginx/sites-available/nextcloud /etc/nginx/sites-enabled/

# Restart Nginx
sudo systemctl restart nginx

echo "Installation complete. Open a web browser and go to http://$server_name/nextcloud to finish the setup."
