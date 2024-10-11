#!/bin/bash

################################################################################
# Script para instalar múltiples instancias de Odoo en entornos virtuales separados
# Escoge la versión de Odoo (16, 17 o 18), el nombre del entorno virtual y el puerto
################################################################################

# Variables generales
OE_USER="odoo"
OE_HOME="/$OE_USER"
OE_SUPERADMIN="admin"  # Cambia esta contraseña por la que prefieras
OE_HOME_EXT="/$OE_USER/${OE_USER}-server"

# Preguntar al usuario qué versión de Odoo quiere instalar
echo "¿Qué versión de Odoo deseas instalar? (16, 17 o 18)"
read OE_VERSION

if [ "$OE_VERSION" != "16" ] && [ "$OE_VERSION" != "17" ] && [ "$OE_VERSION" != "18" ]; then
    echo "Versión de Odoo no válida. Solo puedes instalar la versión 16, 17 o 18."
    exit 1
fi

# Preguntar al usuario el nombre del entorno virtual
echo "Introduce el nombre del entorno virtual para esta instancia:"
read VIRTUAL_ENV_NAME

# Preguntar al usuario el puerto de Odoo
echo "Introduce el puerto en el que se ejecutará Odoo:"
read OE_PORT

# Variables específicas para la instalación
OE_HOME_INSTANCE="${OE_HOME}/${VIRTUAL_ENV_NAME}"  # Ruta de la nueva instancia
OE_CONFIG="${OE_USER}-${VIRTUAL_ENV_NAME}-server"  # Nombre del archivo de configuración
VIRTUAL_ENV="${OE_HOME}/venv-${VIRTUAL_ENV_NAME}"  # Ruta del entorno virtual
OE_LONGPOLLING_PORT=$(($OE_PORT + 1))  # El puerto longpolling será el siguiente al puerto principal

# Actualizar y actualizar el servidor
echo -e "\n---- Actualizando el servidor ----"
sudo apt-get update && sudo apt-get upgrade -y

# Instalar PostgreSQL si no está instalado
echo -e "\n---- Instalando PostgreSQL (si no está ya instalado) ----"
sudo apt-get install postgresql postgresql-server-dev-all -y
sudo su - postgres -c "createuser -s $OE_USER" 2> /dev/null || true

# Crear entorno virtual para esta instancia
echo -e "\n---- Creando entorno virtual para Odoo $OE_VERSION ----"
python3 -m venv $VIRTUAL_ENV
source $VIRTUAL_ENV/bin/activate

# Instalar dependencias del sistema
echo -e "\n---- Instalando dependencias del sistema ----"
sudo apt-get install python3-dev python3-pip python3-setuptools build-essential wget libxslt-dev libzip-dev libldap2-dev libsasl2-dev node-less libjpeg-dev libpq-dev libpng-dev -y

# Clonar el repositorio de Odoo
echo -e "\n---- Clonando el repositorio de Odoo $OE_VERSION ----"
sudo git clone --depth 1 --branch $OE_VERSION https://www.github.com/odoo/odoo $OE_HOME_INSTANCE/

# Instalar las dependencias de Odoo
echo -e "\n---- Instalando dependencias Python de Odoo $OE_VERSION ----"
pip3 install wheel
pip3 install -r $OE_HOME_INSTANCE/requirements.txt

# Crear el archivo de configuración de Odoo
echo -e "\n---- Creando archivo de configuración de Odoo $OE_VERSION ----"
sudo touch /etc/${OE_CONFIG}.conf
sudo su root -c "printf '[options] \n; Este es el password para operaciones de base de datos:\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'admin_passwd = ${OE_SUPERADMIN}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'http_port = ${OE_PORT}\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'logfile = /var/log/${OE_USER}/${OE_CONFIG}.log\n' >> /etc/${OE_CONFIG}.conf"
sudo su root -c "printf 'addons_path=${OE_HOME_INSTANCE}/addons,${OE_HOME_INSTANCE}/custom/addons\n' >> /etc/${OE_CONFIG}.conf"
sudo chown $OE_USER:$OE_USER /etc/${OE_CONFIG}.conf
sudo chmod 640 /etc/${OE_CONFIG}.conf

# Crear el directorio para módulos personalizados
echo -e "\n---- Creando directorio para módulos personalizados de Odoo $OE_VERSION ----"
sudo su $OE_USER -c "mkdir -p ${OE_HOME_INSTANCE}/custom/addons"

# Configuración para iniciar Odoo
echo -e "\n---- Configurando Odoo para iniciar como servicio ----"
cat <<EOF > ~/${OE_CONFIG}
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
[Service]
# Ubuntu/Debian convention:
User=$OE_USER
ExecStart=$OE_HOME_INSTANCE/odoo-bin -c /etc/${OE_CONFIG}.conf
[Install]
WantedBy=default.target
EOF

sudo mv ~/${OE_CONFIG} /etc/systemd/system/${OE_CONFIG}.service
sudo chmod 755 /etc/systemd/system/${OE_CONFIG}.service
sudo systemctl enable ${OE_CONFIG}.service
sudo systemctl start ${OE_CONFIG}.service

deactivate

echo -e "\n¡Instalación completada de Odoo $OE_VERSION con entorno virtual $VIRTUAL_ENV_NAME en el puerto $OE_PORT!"
