#!/bin/bash

# Definir variables
DOMINIO_PRINCIPAL="tu_dominio.com"
DOMINIO_SECUNDARIO="www.tu_dominio.com"

# Actualización del sistema
echo "Actualizando el sistema..."
sudo apt update -y && sudo apt upgrade -y

# Instalación de Nginx
echo "Instalando Nginx..."
sudo apt install nginx -y

# Instalación de PHP y módulos necesarios
echo "Instalando PHP y módulos necesarios..."
sudo apt install php-fpm php-mysql -y

# Configuración de Nginx
echo "Configurando Nginx..."
NGINX_CONFIG="/etc/nginx/sites-available/default"
sudo mv $NGINX_CONFIG ${NGINX_CONFIG}.bak
sudo tee $NGINX_CONFIG > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMINIO_PRINCIPAL $DOMINIO_SECUNDARIO;

    root /var/www/html;
    index index.php index.html index.htm index.nginx-debian.html;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \\.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
    }

    location ~ /\\.ht {
        deny all;
    }
}
EOL

# Verificación de configuración de Nginx
echo "Verificando configuración de Nginx..."
sudo nginx -t

# Reinicio de Nginx para aplicar cambios
echo "Reiniciando Nginx..."
sudo systemctl restart nginx

# Creación de archivo PHP de prueba
echo "Creando archivo PHP de prueba..."
echo "<?php phpinfo(); ?>" | sudo tee /var/www/html/index.php > /dev/null

# Instalación de Certbot para Nginx
echo "Instalando Certbot..."
sudo apt install certbot python3-certbot-nginx -y

# Configuración de SSL con Certbot
echo "Configurando SSL con Certbot..."
sudo certbot --nginx -d $DOMINIO_PRINCIPAL -d $DOMINIO_SECUNDARIO

# Verificación de renovación automática de certificados SSL
echo "Verificando renovación automática de certificados SSL..."
sudo certbot renew --dry-run

echo "¡Configuración completada!"