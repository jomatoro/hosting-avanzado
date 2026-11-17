# Lab 04: Hardening de Apache (evasive, qos, reqtimeout, suexec, security)

## Objetivo
Implementar y validar 5 capas de protección en Apache contra ataques de denegación de servicio lento, inundación de peticiones, abuso de conexiones, escalada de privilegios en CGI e inyecciones web.

## 1. Instalación de paquetes

### En CentOS Stream 9
```bash
sudo dnf install -y epel-release
sudo dnf install -y mod_evasive mod_qos mod_security mod_security_crs httpd-suexec nmap-ncat
# Nota: mod_reqtimeout viene incluido por defecto en httpd
```

### En Debian 13
```bash
sudo apt update
sudo apt install -y libapache2-mod-evasive libapache2-mod-qos libapache2-mod-security2 modsecurity-crs apache2-suexec-pristine netcat-openbsd
sudo a2enmod reqtimeout evasive qos security2 suexec cgi
```

## 2. Despliegue de las configuraciones de prueba
Copia los archivos `.conf` de esta carpeta en `/etc/httpd/conf.d/` (CentOS 9) o `/etc/apache2/conf-available/` y habilítalos con `a2enconf` (Debian 13).

> **Importante:** Prueba cada módulo **de a uno** (comentando o deshabilitando los demás) para que las reglas de bloqueo no interfieran entre sí durante las pruebas.

---

## 3. Ejercicios de Validación

### Prueba A: `mod_reqtimeout` (Mitigación de Slowloris)
1. Activa `security-reqtimeout.conf` y reinicia Apache.
2. Abre una conexión TCP cruda con `nc` sin terminar de enviar las cabeceras HTTP y espera 6 segundos:
   ```bash
   printf "GET / HTTP\(/1.1\r\nHost: localhost\r\\)n" | nc -w 10 127.0.0.1 80
   ```
3. **Resultado esperado:** Apache cortará la conexión antes de los 10 segundos devolviendo `HTTP/1.1 408 Request Timeout`.

### Prueba B: `mod_evasive` (Mitigación de Flood / Fuerza Bruta)
1. Crea el directorio de logs: `sudo mkdir -p /var/log/mod_evasive && sudo chown -R apache:apache /var/log/mod_evasive` (en Debian usa `www-data:www-data`).
2. Activa `security-evasive.conf` y reinicia Apache.
3. Lanza 100 peticiones rápidas con `ab`:
   ```bash
   ab -n 100 -c 10 http://127.0.0
   ```
4. **Resultado esperado:** En el resumen de `ab` verás respuestas `Non-2xx responses` (código `403 Forbidden`) y se creará un archivo `dos-127.0.0.1` en `/var/log/mod_evasive/`.

### Prueba C: `mod_qos` (Límite de conexiones concurrentes por IP)
1. Activa `security-qos.conf` (limita a 3 conexiones simultáneas por IP) y reinicia Apache.
2. Ejecuta una prueba con 20 hilos concurrentes:
   ```bash
   ab -n 200 -c 20 http://127.0.0
   ```
3. **Resultado esperado:** Apache rechazará las conexiones excedentes registrando errores de `mod_qos` en el `error_log`.

### Prueba D: `mod_suexec` (Aislamiento de ejecución CGI)
1. Crea un usuario de prueba y su entorno CGI dentro del DocumentRoot (`/var/www/html/cgi-test` en CentOS o `/var/www/html/cgi-test` en Debian):
   ```bash
   sudo useradd -m alumno1
   sudo mkdir -p /var/www/html/cgi-test
   cat << 'EOF' | sudo tee /var/www/html/cgi-test/id.cgi
   #!/bin/bash
   echo "Content-type: text/plain"
   echo ""
   id
   EOF
   sudo chmod 755 /var/www/html/cgi-test/id.cgi
   sudo chown -R alumno1:alumno1 /var/www/html/cgi-test
   ```
2. Activa `security-suexec.conf` y reinicia Apache.
3. Consulta el script vía web:
   ```bash
   curl http://127.0.0cgi-test/id.cgi
   ```
4. **Resultado esperado:** La salida mostrará `uid=... (alumno1)` en lugar de `apache` o `www-data`. Si falla, revisa `/var/log/httpd/suexec.log` o `/var/log/apache2/suexec.log`.

### Prueba E: `mod_security` (Web Application Firewall - WAF)
1. Activa `security-modsec.conf` y reinicia Apache.
2. Envía una petición simulando un ataque de **SQL Injection** y otra de **XSS**:
   ```bash
   curl -i "http://127.0.0?id=1'%20OR%20'1'='1"
   curl -i "http://127.0.0?q=<script>alert(1)</script>"
   ```
3. **Resultado esperado:** El WAF interceptará ambas peticiones y responderá `HTTP/1.1 403 Forbidden`. Revisa el detalle de la regla disparada en `/var/log/httpd/modsec_audit.log` (o `/var/log/apache2/modsec_audit.log`).

