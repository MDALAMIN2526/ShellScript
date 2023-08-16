#!/bin/bash
# STEP 0 Install git
sudo apt update -y
sudo apt upgrade -y

# Function to check if a package is installed
is_installed() {
    dpkg -l | grep -E "^ii\s+$1" &> /dev/null
}

# Check and install git
if ! is_installed git; then
    sudo apt-get update -y
    sudo apt-get install git -y
fi

# Check and install python-dev
if ! is_installed python3-dev; then
    sudo apt-get update -y
    sudo apt-get install python3-dev -y
fi

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

# Check and install MariaDB
if ! is_installed mariadb-server; then
    sudo apt-get update -y
    sudo apt-get install software-properties-common -y
    sudo apt-get install mariadb-server -y
    sudo mysql_secure_installation
fi

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

# STEP 8: Install Redis
if ! is_installed redis-server; then
    sudo apt-get update -y
    sudo apt-get install redis-server -y
fi
# STEP 9: Install Node.js 14.X package
if ! which node &> /dev/null; then
    sudo apt-get remove nodejs -y
    sudo apt-get remove npm -y
    sudo apt-get update -y
    sudo apt autoremove -y
    sudo apt-get install curl -y
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
    source ~/.profile
    nvm install 14.15.0
fi


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

# STEP 14 Initialize the frappe bench & install frappe latest version
# Prompt for Frappe Bench version
echo "Which version of Frappe Bench would you like to install?"
echo "1. Version 13"
echo "2. Version 14"
read -p "Enter the number corresponding to your choice: " bench_version

if [ "$bench_version" = "1" ]; then
    frappe_branch="version-13"
    erpnext_branch="version-13"
elif [ "$bench_version" = "2" ]; then
    frappe_branch="version-14"
    erpnext_branch="version-14"
else
    echo "Invalid choice. Please enter either 1 or 2."
    exit 1
fi
# STEP 14 Initialize the frappe bench & install frappe latest version
# Initialize the frappe bench & install frappe latest version
if ! bench init --frappe-branch "$frappe_branch" frappe-bench; then
    echo "Failed to initialize frappe bench. Reinstalling Node.js..."
    sudo apt-get remove nodejs -y
    sudo apt-get remove npm -y
    sudo apt-get update -y
    sudo apt autoremove -y
    sudo apt-get install curl -y
    curl https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash
    source ~/.profile
    nvm install 14.15.0
    bench init --frappe-branch "$frappe_branch" frappe-bench
fi
cd frappe-bench/
nohup bench start &

# STEP 15 Create a site in frappe bench
cd frappe-bench/
bench new-site cpm.com
bench use cpm.com

# STEP 16 Install ERPNext latest version in bench & site
bench get-app erpnext --branch "$erpnext_branch"
bench --site cpm.com install-app erpnext

if [ "$bench_version" = "2" ]; then
    bench get-app payments
    bench get-app hrms --branch version-14
    bench get-app https://github.com/MDALAMIN2526/WooCommerceConnector.git
    bench --site cpm.com install-app payments
    bench --site cpm.com install-app hrms
    bench --site cpm.com install-app woocommerceconnector
fi
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
