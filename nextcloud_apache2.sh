#!/bin/bash

# Overview: This script sets up a LAMP stack and installs Nextcloud.

# Update Packages
sudo apt update -y
sudo apt upgrade -y

# Install LAMP Stack
sudo apt install apache2 mysql-server php libapache2-mod-php php-mysql php-xml php-mbstring php-intl php-zip php-gd php-curl php-bcmath php-gmp -y
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

# Secure MySQL Installation (manually set root password)
sudo mysql_secure_installation

# Create MySQL Database
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

# If server_name is not 127.0.0.1, use provided nextcloud.conf
if [ "$server_name" != "127.0.0.1" ]; then
    # Provided nextcloud.conf
    sudo tee /etc/apache2/sites-available/nextcloud.conf > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $server_name
    ServerAlias www.$server_name

    DocumentRoot /var/www/nextcloud/

    # Add this rewrite rule to redirect HTTP to HTTPS
    RewriteEngine On
    RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [R=301,L]

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>
</VirtualHost>

<VirtualHost *:443>
    ServerName $server_name
    ServerAlias www.$server_name

    DocumentRoot /var/www/nextcloud
    SSLEngine on

    # Add the HSTS header
    Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains; preload"

    # Other SSL settings if needed

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>
</VirtualHost>
EOF

    # Enable necessary Apache modules
    sudo a2query -m ssl || sudo a2enmod ssl
    sudo a2query -m rewrite || sudo a2enmod rewrite
    sudo a2query -m headers || sudo a2enmod headers
    sudo a2ensite nextcloud.conf
    sudo a2dissite 000-default.conf
    # Install Certbot and obtain SSL certificate
    sudo apt update -y
    sudo apt install certbot python3-certbot-apache -y
    sudo certbot certonly --apache -d $server_name
else
    # Adjusted nextcloud.conf for localhost
    sudo tee /etc/apache2/sites-available/nextcloud.conf > /dev/null <<EOF
# Adjusted nextcloud.conf for localhost
<VirtualHost *:80>
    ServerName $server_name
    ServerAlias www.$server_name

    DocumentRoot /var/www/nextcloud/

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>
</VirtualHost>
EOF
fi

# Restart Apache
sudo systemctl restart apache2

echo "Installation complete. Open a web browser and go to http://$server_name/nextcloud to finish the setup."
