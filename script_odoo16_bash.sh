#!/bin/bash
################################################################################
# Script para instalar o Odoo no Ubuntu 16.04, 18.04, 20.04 e 22.04 (pode ser usado para outras versões também)
# Autor: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# Este script instalará o Odoo no seu servidor Ubuntu. Ele pode instalar várias instâncias do Odoo
# em um Ubuntu por causa dos diferentes xmlrpc_ports
#-------------------------------------------------------------------------------
# Crie um novo arquivo:
# sudo nano odoo-install.sh
# Coloque este conteúdo nele e depois torne o arquivo executável:
# sudo chmod +x odoo-install.sh
# Execute o script para instalar o Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
# A porta padrão onde esta instância do Odoo será executada (desde que você use o comando -c no terminal)
# Defina como verdadeiro se você quiser instalá-lo, falso se você não precisar ou já tiver instalado.
INSTALL_WKHTMLTOPDF="True"
# Defina a porta padrão do Odoo (você ainda precisa usar -c /etc/odoo-server.conf, por exemplo, para usar isso.)
OE_PORT="8069"
# Escolha a versão do Odoo que você deseja instalar. Por exemplo: 16.0, 15.0, 14.0 ou saas-22. Ao usar 'master', a versão master será instalada.
# IMPORTANTE! Este script contém bibliotecas extras que são especificamente necessárias para o Odoo 16.0
OE_VERSION="16.0"
# Defina isso como Verdadeiro se você quiser instalar a versão empresarial do Odoo!
IS_ENTERPRISE="False"
# Instala o postgreSQL V14 em vez dos padrões (por exemplo, V12 para Ubuntu 20/22) - isso melhora o desempenho
INSTALL_POSTGRESQL_FOURTEEN="True"
# Defina isso como Verdadeiro se você quiser instalar o Nginx!
INSTALL_NGINX="False"
# Defina a senha do superadministrador - se GENERATE_RANDOM_PASSWORD for definido como "True", geraremos automaticamente uma senha aleatória, caso contrário, usaremos esta
OE_SUPERADMIN="admin"
# Defina como "True" para gerar uma senha aleatória, "False" para usar a variável em OE_SUPERADMIN
GENERATE_RANDOM_PASSWORD="True"
OE_CONFIG="${OE_USER}-server"
# Defina o nome do site
WEBSITE_NAME="_"
# Defina a porta padrão de longpolling do Odoo (você ainda precisa usar -c /etc/odoo-server.conf, por exemplo, para usar isso.)
LONGPOLLING_PORT="8072"
# Defina como "True" para instalar o certbot e ter o ssl habilitado, "False" para usar http
ENABLE_SSL="True"
# Forneça o Email para registrar o certificado ssl
ADMIN_EMAIL="odoo@example.com"
##
###  Links para download do WKHTMLTOPDF
## === Ubuntu Trusty x64 & x32 === (para outras distribuições, substitua esses dois links,
## para ter a versão correta do wkhtmltopdf instalada, para uma nota de perigo, consulte
## https://github.com/odoo/odoo/wiki/Wkhtmltopdf ):
## https://www.odoo.com/documentation/16.0/administration/install.html

# Verifique se o sistema operacional é Ubuntu 22.04
if [[ $(lsb_release -r -s) == "22.04" ]]; then
    WKHTMLTOX_X64="https://packages.ubuntu.com/jammy/wkhtmltopdf"
    WKHTMLTOX_X32="https://packages.ubuntu.com/jammy/wkhtmltopdf"
    # O mesmo link funciona para 64 e 32 bits no Ubuntu 22.04
else
    # Para versões mais antigas do Ubuntu
    WKHTMLTOX_X64="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_amd64.deb"
    WKHTMLTOX_X32="https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.$(lsb_release -c -s)_i386.deb"
fi

#--------------------------------------------------
# Atualizar Servidor
#--------------------------------------------------
echo -e "\n---- Atualizar Servidor ----"
# o pacote universe é para o Ubuntu 18.x
sudo add-apt-repository universe
# dependência libpng12-0 para wkhtmltopdf para versões mais antigas do Ubuntu
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install libpq-dev

#--------------------------------------------------
# Instalar Servidor PostgreSQL
#--------------------------------------------------
echo -e "\n---- Instalar Servidor PostgreSQL ----"
if [ $INSTALL_POSTGRESQL_FOURTEEN = "True" ]; then
    echo -e "\n---- Instalando o PostgreSQL V14 devido à escolha do usuário ----"
    sudo curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
    sudo apt-get update
    sudo apt-get install postgresql-14
else
    echo -e "\n---- Instalando a versão padrão do PostgreSQL com base na versão do Linux ----"
    sudo apt-get install postgresql postgresql-server-dev-all -y
fi


echo -e "\n---- Criando o usuário PostgreSQL do ODOO ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Instalar Dependências
#--------------------------------------------------
echo -e "\n--- Instalando Python 3 + pip3 --"
sudo apt-get install python3 python3-pip
sudo apt-get install git python3-cffi build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng-dev libjpeg-dev gdebi -y

echo -e "\n---- Instalar pacotes/requisitos do python ----"
sudo -H pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Instalando nodeJS NPM e rtlcss para suporte a LTR ----"
sudo apt-get install nodejs npm -y
sudo npm install -g rtlcss

#--------------------------------------------------
# Instalar Wkhtmltopdf se necessário
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Instalar wkhtml e colocar atalhos no local correto para o ODOO 13 ----"
  #escolha o correto entre as versões x64 e x32:
  if [ "`getconf LONG_BIT`" == "64" ];then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  

  if [[ $(lsb_release -r -s) == "22.04" ]]; then
    # Ubuntu 22.04 LTS
    sudo apt install wkhtmltopdf -y
  else
      # Para versões mais antigas do Ubuntu
    sudo gdebi --n `basename $_url`
  fi
  
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf não está instalado devido à escolha do usuário!"
fi

echo -e "\n---- Criar usuário do sistema ODOO ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
#O usuário também deve ser adicionado ao grupo sudo'ers.
sudo adduser $OE_USER sudo

echo -e "\n---- Criar diretório de logs ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Instalar ODOO
#--------------------------------------------------
echo -e "\n==== Instalando Servidor ODOO ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    # Instalação do Odoo Enterprise!
    sudo pip3 install psycopg2-binary pdfminer.six
    echo -e "\n--- Criar link simbólico para o node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Autenticação"* ]]; do
        echo "------------------------ATENÇÃO------------------------------"
        echo "Sua autenticação com o Github falhou! Por favor, tente novamente."
        printf "Para clonar e instalar a versão enterprise do Odoo, você \nprecisa ser um parceiro oficial da Odoo e ter acesso a\nhttp://github.com/odoo/enterprise.\n"
        echo "DICA: Pressione ctrl+c para interromper este script."
        echo "-------------------------------------------------------------"
        echo " "
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Adicionado código Enterprise em $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Instalando bibliotecas específicas da Enterprise ----"
    sudo -H pip3 install num2words ofxparse dbfread ebaysdk firebase_admin pyOpenSSL
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Criar diretório de módulo personalizado ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Definindo permissões na pasta principal ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Criar arquivo de configuração do servidor"


sudo touch /etc/${OE_CONFIG}.conf
echo -e "* Criando arquivo de configuração do servidor"
sudo su root -c "printf '[opções] \n; Esta é a senha que permite operações no banco de dados:\n' >> /etc/${OE_CONFIG}.conf"
if [ $GENERATE_RANDOM_PASSWORD = "True" ]; then
    echo -e "* Gerando senha de administração aleatória"
    OE_SUPERADMIN=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)
fi
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
if [ $OE_VERSION > "11.0" ];then
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"

if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Criar arquivo de inicialização"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/odoo-bin --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Adicionando ODOO como um daemon (initscript)
#--------------------------------------------------

echo -e "* Criar arquivo de inicialização"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Fornecido: $OE_CONFIG
# Requerido-Iniciar: \$remote_fs \$syslog
# Requerido-Parar: \$remote_fs \$syslog
# Deve-Iniciar: \$network
# Deve-Parar: \$network
# Iniciar-Padrão: 2 3 4 5
# Parar-Padrão: 0 1 6
# Descrição-Curta: Aplicativos de Negócios Empresariais
# Descrição: Aplicativos de Negócios ODOO
### END INIT INFO
CAMINHO=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NOME=$OE_CONFIG
DESC=$OE_CONFIG
# Especifique o nome do usuário (Padrão: odoo).
USUÁRIO=$OE_USER
# Especifique um arquivo de configuração alternativo (Padrão: /etc/openerp-server.conf).
ARQUIVOCONFIG="/etc/${OE_CONFIG}.conf"
# pidfile
ARQUIVOPID=/var/run/\${NAME}.pid
# Opções adicionais que são passadas para o Daemon.
OPÇÕES_DAEMON="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$ARQUIVOPID ] || return 1
pid=\`cat \$ARQUIVOPID\`
[ -d /proc/\$pid ] && return 0
return 1
}
caso "\${1}" em
start)
echo -n "Iniciando \${DESC}: "
start-stop-daemon --start --quiet --pidfile \$ARQUIVOPID \
--chuid \$USUÁRIO --background --make-pidfile \
--exec \$DAEMON -- \$OPÇÕES_DAEMON
echo "\${NAME}."
;;
stop)
echo -n "Parando \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$ARQUIVOPID \
--oknodo
echo "\${NAME}."
;;
restart|force-reload)
echo -n "Reiniciando \${DESC}: "
start-stop-daemon --stop --quiet --pidfile \$ARQUIVOPID \
--oknodo
sleep 1
start-stop-daemon --start --quiet --pidfile \$ARQUIVOPID \
--chuid \$USUÁRIO --background --make-pidfile \
--exec \$DAEMON -- \$OPÇÕES_DAEMON
echo "\${NAME}."
;;
*)
N=/etc/init.d/\$NAME
echo "Uso: \$NAME {start|stop|restart|force-reload}" >&2
exit 1
;;
esac
exit 0
EOF

echo -e "* Arquivo de Inicialização de Segurança"
sudo mv ~/$OE_CONFIG /etc/init.d/$OE_CONFIG
sudo chmod 755 /etc/init.d/$OE_CONFIG
sudo chown root: /etc/init.d/$OE_CONFIG

echo -e "* Iniciar ODOO na Inicialização"
sudo update-rc.d $OE_CONFIG defaults

#--------------------------------------------------
# Instalar Nginx se necessário
#--------------------------------------------------
if [ $INSTALL_NGINX = "True" ]; then
  echo -e "\n---- Instalando e configurando Nginx ----"
  sudo apt install nginx -y
  cat <<EOF > ~/odoo
servidor {
  ouvir 80;

  # definir o nome do servidor apropriado após definir o domínio
  server_name $WEBSITE_NAME;

  # Adicionar cabeçalhos para o modo de proxy do odoo
  proxy_set_header X-Forwarded-Host \$host;
  proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
  proxy_set_header X-Forwarded-Proto \$scheme;
  proxy_set_header X-Real-IP \$remote_addr;
  add_header X-Frame-Options "SAMEORIGIN";
  add_header X-XSS-Protection "1; mode=block";
  proxy_set_header X-Client-IP \$remote_addr;
  proxy_set_header HTTP_X_FORWARDED_HOST \$remote_addr;

  #   odoo    arquivos de log
  access_log  /var/log/nginx/$OE_USER-access.log;
  error_log       /var/log/nginx/$OE_USER-error.log;

  #   aumentar o tamanho do buffer de proxy
  proxy_buffers   16  64k;
  proxy_buffer_size   128k;

  proxy_read_timeout 900s;
  proxy_connect_timeout 900s;
  proxy_send_timeout 900s;

  #   forçar   tempos limite se o backend morrer
  proxy_next_upstream error   timeout invalid_header  http_500    http_502
  http_503;

  tipos {
    text/less less;
    text/scss scss;
  }

  #   habilitar  compressão de dados
  gzip    on;
  gzip_min_length 1100;
  gzip_buffers    4   32k;
  gzip_types  text/css text/less text/plain text/xml application/xml application/json application/javascript application/pdf image/jpeg image/png;
  gzip_vary   on;
  client_header_buffer_size 4k;
  large_client_header_buffers 4 64k;
  client_max_body_size 0;

  localização / {
    proxy_pass    http://127.0.0.1:$OE_PORT;
    # por padrão, não encaminhar nada
    proxy_redirect off;
  }

  localização /longpolling {
    proxy_pass http://127.0.0.1:$LONGPOLLING_PORT;
  }

  localização ~* .(js|css|png|jpg|jpeg|gif|ico)$ {
    expira 2d;
    proxy_pass http://127.0.0.1:$OE_PORT;
    add_header Cache-Control "public, no-transform";
  }

  # cache de alguns dados estáticos na memória por 60 minutos.
  localização ~ /[a-zA-Z0-9_-]*/static/ {
    proxy_cache_valid 200 302 60m;
    proxy_cache_valid 404      1m;
    proxy_buffering    on;
    expira 864000;
    proxy_pass    http://127.0.0.1:$OE_PORT;
  }
}
EOF

  sudo mv ~/odoo /etc/nginx/sites-available/$WEBSITE_NAME
  sudo ln -s /etc/nginx/sites-available/$WEBSITE_NAME /etc/nginx/sites-enabled/$WEBSITE_NAME
  sudo rm /etc/nginx/sites-enabled/default
  sudo service nginx reload
  sudo su root -c "printf 'proxy_mode = True\n' >> /etc/${OE_CONFIG}.conf"
  echo "Feito! O servidor Nginx está funcionando. A configuração pode ser encontrada em /etc/nginx/sites-available/$WEBSITE_NAME"
else
  echo "Nginx não está instalado devido à escolha do usuário!"
fi

#--------------------------------------------------
# Habilitar SSL com certbot
#--------------------------------------------------

if [ $INSTALL_NGINX = "True" ] && [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "_" ];then
  sudo apt-get update -y
  sudo apt install snapd -y
  sudo snap install core; snap refresh core
  sudo snap install --classic certbot
  sudo apt-get install python3-certbot-nginx -y
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo service nginx reload
  echo "SSL/HTTPS está habilitado!"
else
  echo "SSL/HTTPS não está habilitado devido à escolha do usuário ou por uma má configuração!"
  if $ADMIN_EMAIL = "odoo@example.com";then 
    echo "O Certbot não suporta registrar odoo@example.com. Você deve usar um endereço de e-mail real."
  fi
  if $WEBSITE_NAME = "_";then
    echo "O nome do site está definido como _. Não é possível obter um Certificado SSL para _. Você deve usar um endereço de site real."
  fi
fi

echo -e "* Iniciando Serviço Odoo"
sudo su root -c "/etc/init.d/$OE_CONFIG start"
echo "-----------------------------------------------------------"
echo "Feito! O servidor Odoo está funcionando. Especificações:"
echo "Porta: $OE_PORT"
echo "Serviço de usuário: $OE_USER"
echo "Localização do arquivo de configuração: /etc/${OE_CONFIG}.conf"
echo "Localização do arquivo de log: /var/log/$OE_USER"
echo "Usuário PostgreSQL: $OE_USER"
echo "Localização do código: $OE_USER"
echo "Pasta de Addons: $OE_USER/$OE_CONFIG/addons/"
echo "Senha superadmin (banco de dados): $OE_SUPERADMIN"
echo "Iniciar serviço Odoo: sudo service $OE_CONFIG start"
echo "Parar serviço Odoo: sudo service $OE_CONFIG stop"
echo "Reiniciar serviço Odoo: sudo service $OE_CONFIG restart"
if [ $INSTALL_NGINX = "True" ]; then
  echo "Arquivo de configuração Nginx: /etc/nginx/sites-available/$WEBSITE_NAME"
fi
echo "-----------------------------------------------------------"