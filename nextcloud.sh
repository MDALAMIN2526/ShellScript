#!/bin/bash

# Update Packages
sudo apt update -y
sudo apt upgrade -y

# Install LAMP Stack
sudo apt install apache2 mysql-server php libapache2-mod-php php-mysql php-xml php-mbstring php-intl php-zip php-gd php-curl -y
# Secure MySQL Installation
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
sudo tar -xjvf latest.tar.bz2 -y
sudo rm -r latest.tar.bz2

# Set Permissions
sudo chown -R www-data:www-data /var/www/nextcloud 
# Get Server Name from User
read -p "Enter the server name or domain (e.g., yourdomain.com): " server_name
# Set default server name if user input is empty
if [ -z "$server_name" ]; then
    server_name="127.0.0.1"
fi
# Configure Apache
sudo tee /etc/apache2/sites-available/nextcloud.conf > /dev/null <<EOF
<VirtualHost *:80>
    DocumentRoot /var/www/nextcloud/
    ServerName $server_name

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
    DocumentRoot /var/www/nextcloud

    SSLEngine on
    SSLCertificateFile /path/to/your/certificate.crt
    SSLCertificateKeyFile /path/to/your/private-key.key
    SSLCertificateChainFile /path/to/your/chain.crt (if applicable)
    
</VirtualHost>
EOF

sudo a2ensite nextcloud.conf -y
sudo a2enmod rewrite -y
sudo systemctl restart apache2 -y

echo "Installation complete. Open a web browser and go to http://$server_name/nextcloud to finish the setup."
