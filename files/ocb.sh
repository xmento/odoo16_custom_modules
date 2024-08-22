#!/bin/bash

# Script to install OCB (Odoo Community Backports) on Ubuntu VPS

# Variables
OCB_VERSION="14.0"  # Set your desired OCB version here (e.g., 14.0, 15.0)
OCB_HOME="/opt/ocb"  # Directory where OCB will be installed
OCB_USER="odoo"  # The system user to run the OCB service
OCB_CONF="/etc/ocb.conf"  # OCB configuration file path
OCB_CUSTOM_ADDONS_DIR="$OCB_HOME/custom_addons"  # Directory for custom addons
POSTGRES_VERSION="12"  # PostgreSQL version
OCB_ADMIN_PASSWORD="admin"  # Odoo admin password
OCB_DATABASE="ocb_db"  # The name of the Odoo database

# Update and upgrade system packages
echo "Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

# Install dependencies
echo "Installing dependencies..."
sudo apt-get install -y python3-pip build-essential wget git python3-dev libxml2-dev libxslt1-dev zlib1g-dev libsasl2-dev libldap2-dev libssl-dev libjpeg-dev libpq-dev libffi-dev libjpeg8-dev liblcms2-dev libblas-dev libatlas-base-dev libkrb5-dev

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt-get install -y postgresql-$POSTGRES_VERSION postgresql-server-dev-$POSTGRES_VERSION

# Create PostgreSQL user
echo "Creating PostgreSQL user..."
sudo -u postgres createuser -s $OCB_USER || true

# Create system user for OCB
echo "Creating OCB system user..."
sudo adduser --system --home=$OCB_HOME --group $OCB_USER

# Install OCB
echo "Cloning OCB repository..."
sudo mkdir -p $OCB_HOME
sudo git clone https://github.com/OCA/OCB.git -b $OCB_VERSION $OCB_HOME
sudo chown -R $OCB_USER:$OCB_USER $OCB_HOME

# Install Python dependencies
echo "Installing Python dependencies..."
sudo pip3 install -r $OCB_HOME/requirements.txt

# Set up custom addons directory
echo "Setting up custom addons directory..."
sudo mkdir -p $OCB_CUSTOM_ADDONS_DIR
sudo chown -R $OCB_USER:$OCB_USER $OCB_CUSTOM_ADDONS_DIR

# Configure OCB
echo "Configuring OCB..."
sudo cp $OCB_HOME/debian/odoo.conf $OCB_CONF
sudo chown $OCB_USER:$OCB_USER $OCB_CONF
sudo chmod 640 $OCB_CONF

# Update configuration file
sudo bash -c "cat > $OCB_CONF <<EOF
[options]
addons_path = $OCB_HOME/addons,$OCB_CUSTOM_ADDONS_DIR
admin_passwd = $OCB_ADMIN_PASSWORD
db_host = False
db_port = False
db_user = $OCB_USER
db_password = False
logfile = /var/log/ocb/ocb.log
EOF"

# Set up log directory
echo "Setting up log directory..."
sudo mkdir -p /var/log/ocb
sudo chown $OCB_USER:$OCB_USER /var/log/ocb

# Set up systemd service
echo "Creating systemd service for OCB..."
sudo bash -c "cat > /etc/systemd/system/ocb.service <<EOF
[Unit]
Description=OCB (Odoo Community Backports)
Documentation=https://www.odoo.com/documentation/user/
[Service]
# Ubuntu/Debian convention:
Type=simple
User=$OCB_USER
ExecStart=$OCB_HOME/odoo-bin -c $OCB_CONF
[Install]
WantedBy=multi-user.target
EOF"

# Start OCB service
echo "Starting OCB service..."
sudo systemctl daemon-reload
sudo systemctl start ocb
sudo systemctl enable ocb

# Create OCB database
echo "Creating OCB database..."
sudo -u $OCB_USER $OCB_HOME/odoo-bin -d $OCB_DATABASE --init=base --stop-after-init

echo "OCB installation complete. Access your OCB instance at http://localhost:8069"

