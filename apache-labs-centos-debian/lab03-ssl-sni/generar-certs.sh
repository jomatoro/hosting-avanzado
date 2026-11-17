#!/bin/bash
set -e

CERT_DIR="/etc/ssl/apache-lab"
mkdir -p "$CERT_DIR"

for site in tienda.lab.local blog.lab.local; do
    echo "Generando certificado y contenido para $site..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "${CERT_DIR}/${site}.key" \
        -out "${CERT_DIR}/${site}.crt" \
        -subj "/C=AR/ST=BuenosAires/L=CABA/O=ApacheLab/CN=${site}" 2>/dev/null

    chmod 600 "${CERT_DIR}/${site}.key"
    mkdir -p "/var/www/${site}"
    echo "<h1>Bienvenido a HTTPS en ${site}</h1>" > "/var/www/${site}/index.html"
done

echo "Certificados creados en $CERT_DIR"

