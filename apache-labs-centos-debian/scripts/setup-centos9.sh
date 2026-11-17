#!/bin/bash
set -e

echo "=== [1/4] Actualizando sistema e instalando EPEL en CentOS Stream 9 ==="
dnf install -y epel-release
dnf update -y

echo "=== [2/4] Instalando Apache, herramientas de benchmark y módulos de seguridad ==="
dnf install -y \
    httpd \
    httpd-tools \
    mod_ssl \
    mod_evasive \
    mod_qos \
    mod_security \
    mod_security_crs \
    httpd-suexec \
    openssl \
    curl \
    iproute \
    procps-ng \
    nmap-ncat

echo "=== [3/4] Preparando directorios de logs y permisos base ==="
mkdir -p /var/log/mod_evasive
chown -R apache:apache /var/log/mod_evasive
mkdir -p /etc/ssl/apache-lab

# Crear página de inicio por defecto si no existe
if [ ! -f /var/www/html/index.html ]; then
    echo "<h1>Apache listo en CentOS Stream 9</h1>" > /var/www/html/index.html
fi

# Deshabilitar configuraciones automáticas de módulos de seguridad para que no interfieran en Labs 01-03
for modconf in mod_evasive.conf mod_qos.conf mod_security.conf; do
    if [ -f "/etc/httpd/conf.d/${modconf}" ]; then
        mv "/etc/httpd/conf.d/${modconf}" "/etc/httpd/conf.d/${modconf}.disabled"
    fi
done

echo "=== [4/4] Habilitando e iniciando httpd ==="
systemctl enable --now httpd

echo "Setup de CentOS Stream 9 finalizado correctamente."

