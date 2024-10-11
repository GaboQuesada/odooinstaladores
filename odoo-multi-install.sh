#!/bin/bash

################################################################################
# Script para instalar Odoo 16, 17 y 18 en un solo servidor Ubuntu
################################################################################

# Variables generales
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"

# Instalar PostgreSQL
INSTALL_POSTGRESQL="True"

# Configuración para Odoo 16
OE_VERSION_16="16.0"
OE_PORT_16="8069"
OE_LONGPOLLING_PORT_16="8072"
OE_HOME_16="${OE_HOME}/odoo-16"
OE_CONFIG_16="${OE_USER}-16-server"
VIRTUAL_ENV_16="${OE_HOME}/venv-16"

# Configuración para Odoo 17
OE_VERSION_17="17.0"
OE_PORT_17="8081"
OE_LONGPOLLING_PORT_17="8083"
OE_HOME_17="${OE_HOME}/odoo-17"
OE_CONFIG_17="${OE_USER}-17-server"
VIRTUAL_ENV_17="${OE_HOME}/venv-17"

# Configuración para Odoo 18
OE_VERSION_18="18.0"
OE_PORT_18="8082"
OE_LONGPOLLING_PORT_18="8084"
OE_HOME_18="${OE_HOME}/odoo-18"
OE_CONFIG_18="${OE_USER}-18-server"
VIRTUAL_ENV_18="${OE_HOME}/venv-18"

# Actualizar y actualizar el servidor
echo -e "\n---- Actualizando el servidor ----"
sudo apt-get update && sudo apt-get upgrade -y

# Instalar PostgreSQL si no está instalado
if [ $INSTALL_POSTGRESQL = "True" ]; then
    echo -e "\n---- Instalando PostgreSQL ----"
    sudo apt-get install postgresql postgresql-server-dev-all -y
    sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true
fi

# Función para instalar Odoo
install_odoo () {
    OE_VERSION=$1
    OE_PORT=$2
    OE_LONGPOLLING_PORT=$3
    OE_HOME=$4
    OE_CONFIG=$5
    VIRTUAL_ENV=$6

    echo -e "\n==== Instalando Odoo $OE_VERSION ===="

    # Crear entorno virtual para esta versión
    echo -e "\n---- Creando entorno virtual para Odoo $OE_VERSION ----"
    python3 -m venv $VIRTUAL_ENV
    source $VIRTUAL_ENV/bin/activate

    # Instalar dependencias del sistema
    echo -e "\n---- Instalando dependencias del sistema ----"
    sudo apt-get install python3-dev python3-pip python3-setuptools build-essential wget libxslt-dev libzip-dev libldap2-dev libsasl2-dev node-less libjpeg-dev libpq-dev libpng-dev -y

    # Clonar el repositorio de Odoo
    echo -e "\n---- Clonando el repositorio de Odoo $OE_VERSION ----"
    sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME/

    # Instalar las dependencias de Odoo
    echo -e "\n---- Instalando dependencias Python de Odoo $OE_VERSION ----"
    pip3 install wheel
    pip3 install -r $OE_HOME/requirements.txt

    # Crear el archivo de configuración de Odoo
    echo -e "\n---- Creando archivo de configuración de Odoo $OE_VERSION ----"
    sudo touch /etc/${OE_CONFIG}.conf
    sudo su root -c "printf '[options] \n; Este es el password para operaciones de base de datos:\n' >> /etc/${OE_CONFIG}.conf"
    sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
    sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
    sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
    sudo su root -c "printf 'addons_path=${OE_HOME}/addons,${OE_HOME}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
    sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
    sudo chmod 640 /etc/${OE_CONFIG}.conf

    # Crear el directorio para módulos personalizados
    echo -e "\n---- Creando directorio para módulos personalizados de Odoo $OE_VERSION ----"
    sudo su $OE_USER -c "mkdir -p ${OE_HOME}/custom/addons"

    # Configuración para iniciar Odoo
    echo -e "\n---- Configurando Odoo para iniciar como servicio ----"
    cat <<EOF > ~/${OE_CONFIG}
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
[Service]
# Ubuntu/Debian convention:
User=$OE_USER
ExecStart=$OE_HOME/odoo-bin -c /etc/${OE_CONFIG}.conf
[Install]
WantedBy=default.target
EOF

    sudo mv ~/${OE_CONFIG} /etc/systemd/system/${OE_CONFIG}.service
    sudo chmod 755 /etc/systemd/system/${OE_CONFIG}.service
    sudo systemctl enable ${OE_CONFIG}.service
    sudo systemctl start ${OE_CONFIG}.service

    deactivate
}

# Instalar Odoo 16
install_odoo $OE_VERSION_16 $OE_PORT_16 $OE_LONGPOLLING_PORT_16 $OE_HOME_16 $OE_CONFIG_16 $VIRTUAL_ENV_16

# Instalar Odoo 17
install_odoo $OE_VERSION_17 $OE_PORT_17 $OE_LONGPOLLING_PORT_17 $OE_HOME_17 $OE_CONFIG_17 $VIRTUAL_ENV_17

# Instalar Odoo 18
install_odoo $OE_VERSION_18 $OE_PORT_18 $OE_LONGPOLLING_PORT_18 $OE_HOME_18 $OE_CONFIG_18 $VIRTUAL_ENV_18

echo -e "\n¡Instalación completada de Odoo 16, 17 y 18 con entornos virtuales!"
