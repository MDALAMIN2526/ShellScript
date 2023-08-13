#!/bin/bash
# STEP 0 Install git
sudo apt update -y
sudo apt upgrade -y

# STEP 1 Install git
sudo apt-get install git -y

# STEP 2 Install python-dev
sudo apt-get install python3-dev -y

# STEP 3 Install setuptools and pip
sudo apt-get install python3-setuptools python3-pip -y

# STEP 4 Install virtualenv
sudo apt-get install virtualenv -y

# CHECK PYTHON VERSION
python_version=$(python3 -V 2>&1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+")

# IF VERSION IS 3.8.X RUN
if [[ "$python_version" == "3.8"* ]]; then
    sudo apt install python3.8-venv -y
# IF VERSION IS 3.10.X RUN
elif [[ "$python_version" == "3.10"* ]]; then
    sudo apt install python3.10-venv -y
fi

# STEP 5 Install MariaDB
sudo apt-get install software-properties-common
sudo apt install mariadb-server -y
sudo mysql_secure_installation

# STEP 6 MySQL database development files
sudo apt-get install libmysqlclient-dev -y

# STEP 7 Edit the mariadb configuration (unicode character encoding)
# sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf
# Delete all configuration content to the 50-server.cnf file
sudo truncate -s 0 /etc/mysql/mariadb.conf.d/50-server.cnf
# Add the configuration content to the 50-server.cnf file

sudo tee -a /etc/mysql/mariadb.conf.d/50-server.cnf > /dev/null << EOL
[server]
user = mysql
pid-file = /run/mysqld/mysqld.pid
socket = /run/mysqld/mysqld.sock
basedir = /usr
datadir = /var/lib/mysql
tmpdir = /tmp
lc-messages-dir = /usr/share/mysql
bind-address = 127.0.0.1
query_cache_size = 16M
log_error = /var/log/mysql/error.log

[mysqld]
pid-file                = /run/mysqld/mysqld.pid
basedir                 = /usr
bind-address            = 127.0.0.1
expire_logs_days        = 10
innodb-file-format=barracuda
innodb-file-per-table=1
innodb-large-prefix=1
character-set-client-handshake = FALSE
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[mysql]
default-character-set = utf8mb4
EOL

# Now press (Ctrl-X) to exit

sudo service mysql restart

# ... (Remaining steps remain the same)


sudo service mysql restart

# STEP 8 Install Redis
sudo apt-get install redis-server -y

# STEP 9 Install Node.js 14.X package
sudo apt-get remove nodejs -y
sudo apt-get remove npm -y
sudo apt-get update -y
sudo apt autoremove -y
which node

sudo apt install curl
curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
source ~/.profile
nvm install 14.15.0   -y
which node

# STEP 10 Install Yarn
sudo apt-get install npm -y
sudo npm install -g yarn -y

# STEP 11 Install wkhtmltopdf
sudo apt-get install xvfb libfontconfig wkhtmltopdf -y

# STEP 12 Create a new user
# sudo adduser cpmerp
# sudo usermod -aG sudo cpmerp
# su - cpmerp
chmod -R o+rx /home/$(whoami)

# STEP 13 Install frappe-bench
sudo -H pip3 install frappe-bench
bench --version

# STEP 14 Initialize the frappe bench & install frappe latest versio
bench init --frappe-branch version-13 erp-dir

cd erp-dir/
nohup bench start &

# STEP 15 Create a site in frappe bench
cd erp-dir/
bench new-site cpm.com
bench use cpm.com

# STEP 16 Install ERPNext latest version in bench & site
bench get-app erpnext --branch version-13
bench --site cpm.com install-app erpnext
bench start

# STEP 17 SETUP PRODUCTION SERVER
# Enable scheduler service
bench --site cpm.com enable-scheduler

# Disable maintenance mode
bench --site cpm.com set-maintenance-mode off

# Setup production config
sudo bench setup production $(whoami)

# Setup NGINX web server
bench setup nginx

# Final server setup
sudo supervisorctl restart all
sudo bench setup production $(whoami)
