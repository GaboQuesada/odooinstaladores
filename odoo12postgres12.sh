#!/bin/bash
################################################################################
# Script for installing Odoo on Ubuntu 14.04, 15.04, 16.04 y 18.04 (podría usarse en otras versiones también)
# Autor: Yenthe Van Ginneken
#-------------------------------------------------------------------------------
# Este script instalará Odoo en tu servidor Ubuntu 16.04. Puede instalar múltiples instancias de Odoo
# en un solo Ubuntu usando diferentes xmlrpc_ports
#-------------------------------------------------------------------------------
# Crea un nuevo archivo:
# sudo nano odoo-install.sh
# Coloca este contenido en él y haz el archivo ejecutable:
# sudo chmod +x odoo-install.sh
# Ejecuta el script para instalar Odoo:
# ./odoo-install
################################################################################

OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"
INSTALL_WKHTMLTOPDF="True"
OE_PORT="8069"
OE_VERSION="12.0"
IS_ENTERPRISE="False"
OE_SUPERADMIN="admin"
OE_CONFIG="${OE_USER}-server"

##
###  WKHTMLTOPDF download links
WKHTMLTOX_X64=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_amd64.deb
WKHTMLTOX_X32=https://github.com/wkhtmltopdf/wkhtmltopdf/releases/download/0.12.5/wkhtmltox_0.12.5-1.trusty_i386.deb

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n---- Actualizando el servidor ----"
sudo apt-get install software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository "deb http://mirrors.kernel.org/ubuntu/ xenial main"
sudo apt-get update
sudo apt-get upgrade -y

#--------------------------------------------------
# Install PostgreSQL Server 12
#--------------------------------------------------
echo -e "\n---- Instalando PostgreSQL Server 12 ----"
sudo sh -c "echo 'deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main' > /etc/apt/sources.list.d/pgdg.list"
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install postgresql-12 -y

echo -e "\n---- Creando el usuario ODOO en PostgreSQL para la versión 12 ----"
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

#--------------------------------------------------
# Install Dependencies
#--------------------------------------------------
echo -e "\n--- Instalando Python 3 + pip3 --"
sudo apt-get install git python3 python3-pip build-essential wget python3-dev python3-venv python3-wheel libxslt-dev libzip-dev libldap2-dev libsasl2-dev python3-setuptools node-less libpng12-0 gdebi -y

echo -e "\n---- Instalando paquetes y dependencias Python ----"
sudo pip3 install -r https://github.com/odoo/odoo/raw/${OE_VERSION}/requirements.txt

echo -e "\n---- Instalando nodeJS, NPM y rtlcss para soporte LTR ----"
sudo apt-get install nodejs npm
sudo npm install -g rtlcss

#--------------------------------------------------
# Install Wkhtmltopdf if needed
#--------------------------------------------------
if [ $INSTALL_WKHTMLTOPDF = "True" ]; then
  echo -e "\n---- Instalando wkhtml y ubicando accesos directos en los lugares correctos para ODOO 12 ----"
  if [ "`getconf LONG_BIT`" == "64" ]; then
      _url=$WKHTMLTOX_X64
  else
      _url=$WKHTMLTOX_X32
  fi
  sudo wget $_url
  sudo gdebi --n `basename $_url`
  sudo ln -s /usr/local/bin/wkhtmltopdf /usr/bin
  sudo ln -s /usr/local/bin/wkhtmltoimage /usr/bin
else
  echo "Wkhtmltopdf no se instaló debido a la elección del usuario."
fi

echo -e "\n---- Creando usuario del sistema ODOO ----"
sudo adduser --system --quiet --shell=/bin/bash --home=$OE_HOME --gecos 'ODOO' --group $OE_USER
sudo adduser $OE_USER sudo

echo -e "\n---- Creando directorio de logs ----"
sudo mkdir /var/log/$OE_USER
sudo chown $OE_USER:$OE_USER /var/log/$OE_USER

#--------------------------------------------------
# Install ODOO
#--------------------------------------------------
echo -e "\n==== Instalando ODOO Server ===="
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_EXT/

if [ $IS_ENTERPRISE = "True" ]; then
    echo -e "\n--- Creando enlace simbólico para node"
    sudo ln -s /usr/bin/nodejs /usr/bin/node
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise"
    sudo su $OE_USER -c "mkdir $OE_HOME/enterprise/addons"

    GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    while [[ $GITHUB_RESPONSE == *"Authentication"* ]]; do
        echo "------------------------ADVERTENCIA------------------------------"
        echo "¡Tu autenticación con Github ha fallado! Inténtalo de nuevo."
        echo "TIP: Presiona ctrl+c para detener este script."
        GITHUB_RESPONSE=$(sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/enterprise "$OE_HOME/enterprise/addons" 2>&1)
    done

    echo -e "\n---- Agregado el código de Enterprise bajo $OE_HOME/enterprise/addons ----"
    echo -e "\n---- Instalando librerías específicas de Enterprise ----"
    sudo pip3 install num2words ofxparse
    sudo npm install -g less
    sudo npm install -g less-plugin-clean-css
fi

echo -e "\n---- Creando directorio de módulos personalizados ----"
sudo su $OE_USER -c "mkdir $OE_HOME/custom"
sudo su $OE_USER -c "mkdir $OE_HOME/custom/addons"

echo -e "\n---- Configurando permisos en la carpeta home ----"
sudo chown -R $OE_USER:$OE_USER $OE_HOME/*

echo -e "* Creando archivo de configuración del servidor"

sudo touch /etc/${OE_CONFIG}.conf
sudo su root -c "printf '[options] \n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'xmlrpc_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
if [ $IS_ENTERPRISE = "True" ]; then
    sudo su root -c "printf 'addons_path=${OE_HOME}/enterprise/addons,${OE_HOME_EXT}/addons\n' >> /etc/${OE_CONFIG}.conf"
else
    sudo su root -c "printf 'addons_path=${OE_HOME_EXT}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
fi
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

echo -e "* Creando archivo de inicio"
sudo su root -c "echo '#!/bin/sh' >> $OE_HOME_EXT/start.sh"
sudo su root -c "echo 'sudo -u $OE_USER $OE_HOME_EXT/openerp-server --config=/etc/${OE_CONFIG}.conf' >> $OE_HOME_EXT/start.sh"
sudo chmod 755 $OE_HOME_EXT/start.sh

#--------------------------------------------------
# Añadiendo ODOO como un daemon (initscript)
#--------------------------------------------------

echo -e "* Creando archivo init"
cat <<EOF > ~/$OE_CONFIG
#!/bin/sh
### BEGIN INIT INFO
# Proporciona: $OE_CONFIG
# Requiere-Inicio: \$remote_fs \$syslog
# Requiere-Detener: \$remote_fs \$syslog
# Debería-Iniciar: \$network
# Debería-Detener: \$network
# Default-Start: 2 3 4 5
# Default-Stop: 0 1 6
# Breve-Descripción: Aplicaciones Empresariales
# Descripción: Aplicaciones Empresariales ODOO
### END INIT INFO
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/bin
DAEMON=$OE_HOME_EXT/odoo-bin
NAME=$OE_CONFIG
DESC=$OE_CONFIG
USER=$OE_USER
CONFIGFILE="/etc/${OE_CONFIG}.conf"
PIDFILE=/var/run/\${NAME}.pid
DAEMON_OPTS="-c \$CONFIGFILE"
[ -x \$DAEMON ] || exit 0
[ -f \$CONFIGFILE ] || exit 0
checkpid() {
[ -f \$PIDFILE ] ||
