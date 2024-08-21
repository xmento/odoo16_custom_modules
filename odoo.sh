#!/bin/bash
################################################################################
# Author: Abdelmajid Elhamdaoui. Refrence: Yenthe Van Ginneken
################################################################################
 
## Fixed parameters
# Odoo
OE_USER="odoo"
OE_HOME="/opt/$OE_USER"
OE_HOME_EXT="/opt/$OE_USER/odoo-server"
INSTALL_WKHTMLTOPDF="True"
INSTALL_POSTGRESQL="False"
CREATE_USER_POSTGRESQL="True"
INSTALL_NGINX="False"  # Removed space
ADD_SSL="False"  # Removed space
SSL_PEM_KEY="False"  # Removed space
SSL_PRV_KEY="False"  # Removed space
OE_PORT="8017"
SERVER_NAME="localhost"  # Removed space
OE_VERSION="17.0"  # OR 16.0
IS_ENTERPRISE="False"
OE_SUPERADMIN="ODOO@ADMIN"
OE_CONFIG="${OE_USER}-server"

# Set the database config
DB_HOST="127.0.0.1"
DB_PORT="5432"
DB_USER=$OE_USER
DB_PASSWORD="Odoo17@Legend/mjid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"

# OCA Modules
REP_OCA_WEB="https://github.com/OCA/web.git"
REP_OCA_SERVER_TOOLS="https://github.com/OCA/server-tools.git"
REP_OCA_SERVER_UX="https://github.com/OCA/server-ux.git"
REP_OCA_REPORT_ENGINE="https://github.com/OCA/reporting-engine.git"
REP_OCA_ACC_FIN_TOOLS="https://github.com/OCA/account-financial-tools.git"
REP_QUEUE="https://github.com/OCA/queue.git"
REP_CUSTOM_1="False"
REP_CUSTOM_1_NAME=""
REP_CUSTOM_1_BRANCH=$OE_VERSION

# WKHTMLTOPDF download links
WKHTMLTOX_X64="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_amd64.deb"
WKHTMLTOX_X32="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.bionic_i386.deb"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Update Server ----"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server
#--------------------------------------------------
if [ "$INSTALL_POSTGRESQL" = "True" ]; then
	echo -e "\n---- Install PostgreSQL Server ----"
	sudo apt-get install postgresql -y

	echo -e "\n---- Creating the ODOO PostgreSQL User  ----"
	sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true
else
	sudo apt install postgresql-client-common
	sudo apt-get install -y postgresql-client
	echo -e "\nPOSTGRESQL isn't installed due to the choice of the user! No PostgreSQL user has been created"
fi

sudo apt install postgresql-client
#psql -U postgres -c "ALTER USER $OE_USER WITH PASSWORD '$DB_PASSWORD'"

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
sudo pip3 install --upgrade pip
sudo apt install npm -y
sudo npm install -g rtlcss
sudo apt-get install python3-pip libpq-dev libldap2-dev libsasl2-dev libssl-dev libffi-dev build-essential -y
sudo apt-get install python3.10-dev -y

echo -e "\n---- Install/upgrade Python 3 Pip and other dependencies ----"
# sudo apt install git python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less -y

echo -e "\n---- Install tool packages ----"
# sudo apt-get install wget git python3-pip gdebi-core -y

echo -e "\n---- Install python packages/libraries ----"
# sudo pip3 install Babel decorator docutils ebaysdk feedparser gevent html2text Jinja2 lxml Mako MarkupSafe mock num2words ofxparse passlib Pillow psutil psycogreen pydot pyparsing PyPDF2 pyserial python-dateutil python-openid pytz pyusb PyYAML qrcode reportlab requests six suds-jurko vatnumber vobject XlsxWriter xlwt xlrd gdata
# sudo pip3 install greenlet==1.1.0
# sudo pip3 install libsass==0.17.0
# sudo pip3 install Werkzeug==0.14.1
echo -e "\n--- Install other required packages"
# sudo apt-get install node-clean-css -y
# sudo apt-get install node-less -y
# sudo apt-get install python3-gevent -y
# sudo apt-get install python3-psycopg2 -y

# After last update in Ubuntu 18.04 LTS
# sudo pip3 install babel PyPDF2 passlib werkzeug lxml decorator Pillow psutil html2text docutils suds-jurko
# sudo pip3 install matplotlib
# sudo apt-get install python3-reportlab
# sudo apt-get install python3-dateutil python3-psycopg2

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ "$INSTALL_WKHTMLTOPDF" = "True" ]; then
  echo -e "\n---- Install wkhtml and place shortcuts in correct place for ODOO ----"
  # Pick the correct one from x64 & x32 versions:
  if [ "$(getconf LONG_BIT)" = "64" ]; then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo dpkg -i "$(basename $_url)"
  sudo apt install -f -y
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf isn't installed due to the choice of the user!"
fi

echo -e "\n---- Create ODOO system user ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
# The user should also be added to the sudo'ers group.
sudo adduser $OE_USER sudo

echo -e "\n---- Create Log directory ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Installing ODOO Server ===="
sudo apt install git -y
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

# Install requirements for Odoo
sudo pip3 install wheel
pip3 install --upgrade pip
sudo pip3 install -r $OE_HOME_EXT/requirements.txt

if [ "$IS_ENTERPRISE" = "True" ]; then
    # Odoo Enterprise install!
    echo -e "\n--- Create symlink for node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------WARNING------------------------------"
        echo "Your authentication with Github has failed! Please try again."
        printf "In order to clone and install the Odoo enterprise version you \nneed to be an official Odoo partner and you need access to\nhttp://github.com/odoo/enterprise.\n"
        echo "TIP: Press ctrl+c to stop this script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Added Enterprise code under $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Installing Enterprise specific libraries ----"
    sudo apt-get install nodejs npm -y
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---------------------------OCA----------------------------"
sudo su $OE_USER -c "mkdir $OE_HOME/OCA"

if [ "$REP_OCA_WEB" != "False" ]; then
	echo -e "\n==== Download OCA WEB ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/OCA/web"
	sudo git clone --depth 1 --branch $OE_VERSION $REP_OCA_WEB $OE_HOME/OCA/web
fi

if [ "$REP_OCA_SERVER_TOOLS" != "False" ]; then
	echo -e "\n==== Download OCA Server-tools ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/OCA/server-tools"
	sudo git clone --depth 1 --branch $OE_VERSION $REP_OCA_SERVER_TOOLS $OE_HOME/OCA/server-tools
fi

if [ "$REP_OCA_SERVER_UX" != "False" ]; then
	echo -e "\n==== Download OCA SERVER-UX ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/OCA/server-ux"
	sudo git clone --depth 1 --branch $OE_VERSION $REP_OCA_SERVER_UX $OE_HOME/OCA/server-ux
fi

if [ "$REP_OCA_REPORT_ENGINE" != "False" ]; then
	echo -e "\n==== Download OCA Report-engine ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/OCA/report-engine"
	sudo git clone --depth 1 --branch $OE_VERSION $REP_OCA_REPORT_ENGINE $OE_HOME/OCA/report-engine
	echo -e "\n==== Download OCA QUEUE ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/OCA/queue"
	sudo git clone --depth 1 --branch $OE_VERSION $REP_QUEUE $OE_HOME/OCA/queue
fi

if [ "$REP_OCA_ACC_FIN_TOOLS" != "False" ]; then
	echo -e "\n==== Download OCA Account-Financial-Tools ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/OCA/account-financial-tools"
	sudo git clone --depth 1 --branch $OE_VERSION $REP_OCA_ACC_FIN_TOOLS $OE_HOME/OCA/account-financial-tools
fi

echo -e "\n---- Create custom module directory ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

if [ "$REP_CUSTOM_1" != "False" ]; then
	echo -e "\n==== Download REP_CUSTOM_1 custom ===="
	sudo su $OE_USER -c "mkdir $OE_HOME/custom/$REP_CUSTOM_1_NAME"
	sudo git clone --depth 1 --branch $REP_CUSTOM_1_BRANCH $REP_CUSTOM_1 $OE_HOME/custom/$REP_CUSTOM_1_NAME
fi

echo -e "\n---- Setting permissions on home folder ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

# ---- INSTALL GEOIP database ---
sudo apt-get install geoip-database -y
# Download manually the files GeoLite2-City.mmdb and GeoLite2-Country.mmdb from https://dev.maxmind.com/geoip/geolite2-free-geolocation-data
# mv ~/Downloads/GeoLite2-City.mmdb /usr/share/GeoIP/
# mv ~/Downloads/GeoLite2-Country.mmdb /usr/share/GeoIP/
# Test it in your odoo website : <h1 class="text-center" t-esc="request.geoip.country.name or 'geoip failure'"/>

echo -e "* Create server config file"
sudo su root -c "echo '[options]' > /etc/${OE_CONFIG}.conf"
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Change server config file"
sudo su root -c "echo 'admin_passwd = $OE_SUPERADMIN' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'db_host = $DB_HOST' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'db_port = $DB_PORT' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'db_user = $DB_USER' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'db_password = $DB_PASSWORD' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo -n 'addons_path = ' >> /etc/${OE_CONFIG}.conf"
if [ "$IS_ENTERPRISE" = "True" ]; then
    sudo su root -c "echo -n '$OE_HOME/enterprise/addons,$OE_HOME_EXT/addons,$OE_HOME/custom/addons' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "echo -n '$OE_HOME_EXT/addons,$OE_HOME/custom/addons' >> /etc/${OE_CONFIG}.conf"
fi

if [ "$REP_OCA_WEB" != "False" ]; then
	sudo su root -c "echo -n ',$OE_HOME/OCA/web' >> /etc/${OE_CONFIG}.conf"
fi

if [ "$REP_OCA_SERVER_TOOLS" != "False" ]; then
	sudo su root -c "echo -n ',$OE_HOME/OCA/server-tools' >> /etc/${OE_CONFIG}.conf"
fi

if [ "$REP_OCA_SERVER_UX" != "False" ]; then
	sudo su root -c "echo -n ',$OE_HOME/OCA/server-ux' >> /etc/${OE_CONFIG}.conf"
fi

if [ "$REP_OCA_REPORT_ENGINE" != "False" ]; then
	sudo su root -c "echo -n ',$OE_HOME/OCA/report-engine' >> /etc/${OE_CONFIG}.conf"
	sudo su root -c "echo -n ',$OE_HOME/OCA/queue' >> /etc/${OE_CONFIG}.conf"
fi

if [ "$REP_OCA_ACC_FIN_TOOLS" != "False" ]; then
	sudo su root -c "echo -n ',$OE_HOME/OCA/account-financial-tools' >> /etc/${OE_CONFIG}.conf"
fi

sudo su root -c "echo ' ' >> /etc/${OE_CONFIG}.conf"

# Logfile
sudo su root -c "echo 'logfile = /var/log/$OE_USER/$OE_CONFIG$1.log' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'logrotate = True' >> /etc/${OE_CONFIG}.conf"

echo -e "* Change default xmlrpc port"
sudo su root -c "echo 'xmlrpc_port = $OE_PORT' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'gevent_port = 8072' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "echo 'proxy_mode = True' >> /etc/${OE_CONFIG}.conf"

echo -e "* Create startup file"
sudo su root -c "echo '#!/bin/sh' > $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Install and Configure Nginx (Optional)
#--------------------------------------------------
if [ "$INSTALL_NGINX" = "True" ]; then
    echo -e "* Install, config Nginx and SSL"
    sudo apt install nginx -y
    
    if [ "$ADD_SSL" = "True" ] && [ "$SSL_PEM_KEY" != "False" ] && [ "$SSL_PRV_KEY" != "False" ]; then
        sudo su root -c "echo '$CONTENT_NGINX' > /etc/nginx/sites-available/$OE_USER"
        sudo ln -s /etc/nginx/sites-available/$OE_USER /etc/nginx/sites-enabled/$OE_USER 
        sudo chown root:root /etc/nginx/sites-available/$OE_USER
        sudo chmod 775 /etc/nginx/sites-available/$OE_USER
        
        sudo chown root:root /etc/nginx/sites-enabled/$OE_USER
        sudo chmod 775 /etc/nginx/sites-enabled/$OE_USER
    fi
    sudo service nginx restart
fi

#--------------------------------------------------
# Start Odoo Service and Enable on Boot
#--------------------------------------------------
echo -e "* Start ODOO on Startup"
sudo update-rc.d $OE_CONFIG defaults

echo -e "* Starting Odoo Service"
sudo su root -c "/etc/init.d/$OE_CONFIG start"

echo "-----------------------------------------------------------"
echo "Done! The Odoo server is up and running. Specifications:"
echo "Port: $OE_PORT"
echo "User service: $OE_USER"
echo "User PostgreSQL: $OE_USER"
echo "Code location: $OE_HOME"
echo "Addons folder: $OE_HOME/custom/addons/"
echo "Start Odoo service: sudo service $OE_CONFIG start"
echo "Stop Odoo service: sudo service $OE_CONFIG stop"
echo "Restart Odoo service: sudo service $OE_CONFIG restart"
