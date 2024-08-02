#!/bin/sh

# Define variables
USERNAME="cpm"
PASSWORD="Asdf@1234"
DB_NAME="saas_cpm_erp"
DB_USER="cpm"
DB_PASS="Asdf@1234"
REPO_URL="https://github.com/MDALAMIN2526/saascpmerp.git"
BRANCH="development"
PROJECT_DIR="/var/www/saascpmerp"
DB_BACKUP_FILE="storage/db_backup/saas_cpm_erp.sql"

# Create user and set password
adduser -D $USERNAME
echo "$USERNAME:$PASSWORD" | chpasswd

# Add user to sudoers
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Install necessary packages
apk update
apk add sudo openssh-server nginx php8 php8-fpm php8-openssl php8-pdo php8-mbstring php8-tokenizer php8-json php8-curl php8-session php8-dom php8-fileinfo php8-opcache php8-ctype php8-phar php8-xml php8-mysqli php8-pdo_mysql mariadb mariadb-client phpmyadmin git

# Start and enable services
rc-update add sshd
rc-update add nginx
rc-update add php-fpm8
rc-update add mariadb
rc-service sshd start
rc-service nginx start
rc-service php-fpm8 start
rc-service mariadb setup
rc-service mariadb start

# Set MySQL root password
mysqladmin -u root password "$PASSWORD"

# Create database and user
mysql -u root -p"$PASSWORD" -e "CREATE DATABASE $DB_NAME;"
mysql -u root -p"$PASSWORD" -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -u root -p"$PASSWORD" -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
mysql -u root -p"$PASSWORD" -e "FLUSH PRIVILEGES;"

# Clone the project repository
sudo -u $USERNAME mkdir -p $PROJECT_DIR
sudo -u $USERNAME git clone -b $BRANCH $REPO_URL $PROJECT_DIR

# Import the database
mysql -u $DB_USER -p"$DB_PASS" $DB_NAME < $PROJECT_DIR/$DB_BACKUP_FILE

# Set file permissions
chmod -R 777 $PROJECT_DIR/storage
chmod -R 777 $PROJECT_DIR/storage/framework
chmod -R 777 $PROJECT_DIR/storage/logs
chmod -R 777 $PROJECT_DIR/storage/uploads
chmod -R 777 $PROJECT_DIR/bootstrap/cache
chmod -R 777 $PROJECT_DIR/resources/lang

# Configure nginx for the Laravel project
cat <<EOL > /etc/nginx/conf.d/$USERNAME.conf
server {
    listen 80;
    server_name localhost;

    root $PROJECT_DIR/public;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_index index.php;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

# Restart nginx to apply changes
rc-service nginx restart

echo "Setup complete. The Laravel project is hosted and the database has been imported."
