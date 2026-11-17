#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/4] Actualizando índices de paquetes en Debian 13 ==="
apt-get update -y

echo "=== [2/4] Instalando Apache2, utilidades y módulos de seguridad ==="
apt-get install -y \
    apache2 \
    apache2-utils \
    libapache2-mod-evasive \
    libapache2-mod-qos \
    libapache2-mod-security2 \
    modsecurity-crs \
    apache2-suexec-pristine \
    openssl \
    curl \
    iproute2 \
    procps \
    netcat-openbsd

echo "=== [3/4] Preparando directorios y desactivando módulos intrusivos por defecto ==="
mkdir -p /var/log/mod_evasive
chown -R www-data:www-data /var/log/mod_evasive
mkdir -p /etc/ssl/apache-lab

# Asegurar que en Debian 13 el DocumentRoot base coincida con /var/www/html
echo "<h1>Apache listo en Debian 13</h1>" > /var/www/html/index.html

# Dejar deshabilitados los módulos del Lab 04 para no afectar Labs 01-03
a2dismod -f evasive qos security2 suexec ssl 2>/dev/null || true

echo "=== [4/4] Habilitando e iniciando apache2 ==="
systemctl enable --now apache2

echo "Setup de Debian 13 finalizado correctamente."

