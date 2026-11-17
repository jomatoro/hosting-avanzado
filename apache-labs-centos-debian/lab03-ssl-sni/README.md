# Lab 03: Certificados SSL/TLS con Múltiples VirtualHosts (SNI)

## Objetivo
Habilitar HTTPS en dos dominios distintos (`tienda.lab.local` y `blog.lab.local`) alojados en la misma dirección IP y puerto `443` mediante **SNI (Server Name Indication)**, forzando la redirección desde HTTP.

## 1. Habilitar módulo SSL
* **CentOS 9:**
  ```bash
  sudo dnf install -y mod_ssl
  ```
* **Debian 13:**
  ```bash
  sudo a2enmod ssl
  ```

## 2. Generar certificados autofirmados y sitios
Otorga permisos de ejecución al script incluido y ejecútalo:
```bash
chmod +x generar-certs.sh
sudo ./generar-certs.sh
```

## 3. Activar configuración SSL
* **CentOS 9:** Copia `ssl-multi-vhosts.conf` a `/etc/httpd/conf.d/` y reinicia `httpd`.
* **Debian 13:** Copia `ssl-multi-vhosts.conf` a `/etc/apache2/sites-available/`, ejecuta `sudo a2ensite ssl-multi-vhosts` y reinicia `apache2`.

## 4. Validación de SNI y Redirección
1. Verifica que HTTP (`80`) redirige con código `301` hacia HTTPS (`443`):
   ```bash
   curl -I -H "Host: tienda.lab.local" http://127.0.0.1
   ```
2. Verifica que Apache entrega el certificado correcto según el dominio solicitado por SNI:
   ```bash
   echo | openssl s_client -connect 127.0.0.1:443 -servername tienda.lab.local 2>/dev/null | openssl x509 -noout -subject
   echo | openssl s_client -connect 127.0.0.1:443 -servername blog.lab.local 2>/dev/null | openssl x509 -noout -subject
   ```
3. Prueba una petición HTTPS real ignorando la advertencia de certificado autofirmado (`-k`):
   ```bash
   curl -k --resolve tienda.lab.local:443:127.0.0.1 https://lab.local
   curl -k --resolve blog.lab.local:443:127.0.0.1 https://lab.local
   ```

