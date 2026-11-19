# 🚀 Guía Avanzada de Servidor Web Apache (SSL, Rendimiento y Seguridad)

Este repositorio contiene el resumen teórico y una guía completa de laboratorios prácticos con **verificación de ataques y contramedidas** sobre **Apache HTTP Server**, cubriendo certificados SSL/TLS, optimización de rendimiento mediante MPM, control de acceso y defensa contra ataques DDoS/Web.

> **Compatibilidad:** Todos los ejercicios prácticos están adaptados para ejecutarse tanto en **Debian 13 (Trixie)** (`apache2`) como en **CentOS Stream 9** (`httpd`).

---

## 📑 Índice de Contenidos
1. [Certificados SSL/TLS (Docs 01, 04 y 05)](#1-certificados-ssltls)
2. [Rendimiento y Perfiles Multiproceso - MPM (Docs 02, 06 y 07)](#2-rendimiento-y-perfiles-multiproceso-mpm)
3. [Seguridad, Control de Acceso y Mitigación de Ataques (Docs 03, 08 y 09)](#3-seguridad-control-de-acceso-y-mitigacion-de-ataques)
   * [3.1 Auditoría de Procesos y Permisos](#31-auditoria-de-procesos-y-permisos)
   * [3.2 Control de Acceso por IP, Subred, `.htaccess` y `htpasswd`](#32-control-de-acceso-por-ip-subred-htaccess-y-htpasswd)
   * [3.3 Hardening de Información y Bloqueo de Método TRACE (XST)](#33-hardening-de-informacion-y-bloqueo-de-metodo-trace-xst)
   * [3.4 Mitigación de HTTP Flood con `mod_evasive`](#34-mitigacion-de-http-flood-con-mod_evasive)
   * [3.5 Mitigación de Slowloris con `mod_qos` y `mod_reqtimeout`](#35-mitigacion-de-slowloris-con-mod_qos-y-mod_reqtimeout)
   * [3.6 Aislamiento de VirtualHosts con `mod_suexec`](#36-aislamiento-de-virtualhosts-con-mod_suexec)
   * [3.7 Cortafuegos de Aplicaciones Web (WAF) con `mod_security`](#37-cortafuegos-de-aplicaciones-web-waf-con-mod_security)

---

## 1. Certificados SSL/TLS

### 📖 Resumen Teórico
* **SSL/TLS:** Protocolos criptográficos que cifran la comunicación cliente-servidor mediante una clave privada secreta y un certificado público X.509.
* **Certificados Autofirmados:** Generados localmente con `openssl`. Cifran el canal pero generan advertencias en navegadores al no estar emitidos por una CA pública.

### 🛠️ Ejercicio Práctico 1: Implementación de HTTPS y Redirección

#### 1. Generar clave privada y certificado X.509 (RSA 4096 bits, 3 años)
```bash
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 1095 -newkey rsa:4096 \
  -subj "/C=AR/ST=BuenosAires/L=CABA/O=LabApache/CN=hosting-avanzado.intranet" \
  -keyout /etc/ssl/private/hosting-avanzado.intranet.key \
  -out /etc/ssl/certs/hosting-avanzado.intranet.crt
```

#### 2. Configurar parámetros SSL seguros
* **Debian 13:** `/etc/apache2/conf-available/ssl-params.conf` (`a2enmod ssl headers && a2enconf ssl-params`)
* **CentOS 9:** `/etc/httpd/conf.d/ssl-params.conf` (`dnf install -y mod_ssl`)

```apache
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLHonorCipherOrder On
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
SSLCompression off
SSLSessionTickets Off
```

#### 3. Configurar VirtualHost (HTTP -> HTTPS)
* **Debian 13:** `/etc/apache2/sites-available/hosting-avanzado.intranet.conf` (`a2ensite hosting-avanzado.intranet.conf`)
* **CentOS 9:** `/etc/httpd/conf.d/hosting-avanzado.intranet.conf`

```apache
<VirtualHost *:80>
    ServerName hosting-avanzado.intranet
    Redirect "/" "https://hosting-avanzado.intranet/"
</VirtualHost>

<VirtualHost *:443>
    ServerAdmin admin@hosting-avanzado.intranet
    ServerName hosting-avanzado.intranet
    DocumentRoot /var/www/hosting-avanzado.intranet
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/hosting-avanzado.intranet.crt
    SSLCertificateKeyFile /etc/ssl/private/hosting-avanzado.intranet.key
</VirtualHost>
```

#### ✅ Verificación SSL/TLS
```bash
echo "127.0.0.1 hosting-avanzado.intranet" >> /etc/hosts
# Debe mostrar redirección 302 hacia https:// y luego 200 OK con cabeceras X-Frame-Options
curl -kIL http://hosting-avanzado.intranet
# Verificar que TLSv1.1 sea rechazado (debe fallar el handshake)
openssl s_client -connect hosting-avanzado.intranet:443 -tls1_1
```

---

## 2. Rendimiento y Perfiles Multiproceso (MPM)

### 📖 Resumen Teórico

| Característica | `mpm_prefork` | `mpm_worker` | `mpm_event` |
| :--- | :--- | :--- | :--- |
| **Arquitectura** | 1 proceso hijo por conexión (sin hilos). | Procesos hijos con múltiples **hilos**. | Igual que `worker` + hilo dedicado a *Keep-Alive*. |
| **Consumo RAM** | Alto. | Bajo. | Muy bajo y altamente escalable. |
| **Caso de Uso** | Bibliotecas no *thread-safe* (`mod_php` clásico). | Contenido estático y concurrencia media. | Alto tráfico simultáneo y PHP-FPM. |

### 🛠️ Ejercicio Práctico 2: Tuning de `mpm_event` y Benchmark con `ab`
1. **Activar `mpm_event`:**
   * **Debian 13:** `systemctl stop apache2 && a2dismod mpm_prefork mpm_worker && a2enmod mpm_event && systemctl start apache2`
   * **CentOS 9:** En `/etc/httpd/conf.modules.d/00-mpm.conf` dejar descomentado solo `LoadModule mpm_event_module modules/mod_mpm_event.so` y ejecutar `systemctl restart httpd`.
2. **Directivas de ajuste (`/etc/apache2/mods-available/mpm_event.conf` o `/etc/httpd/conf.d/mpm.conf`):**
   ```apache
   <IfModule mpm_event_module>
       StartServers             2
       MinSpareThreads         25
       MaxSpareThreads         75
       ThreadLimit             64
       ThreadsPerChild         25
       MaxRequestWorkers      150
       MaxConnectionsPerChild   0
   </IfModule>
   ```
3. **✅ Verificación de Rendimiento:**
   ```bash
   # Instalar herramienta: apt install -y apache2-utils (Debian) | dnf install -y httpd-tools (CentOS)
   apachectl -M | grep mpm
   ab -k -n 1000 -c 100 -H 'Accept-Encoding: gzip,deflate' https://hosting-avanzado.intranet/
   ```

---

## 3. Seguridad, Control de Acceso y Mitigación de Ataques

### 3.1 Auditoría de Procesos y Permisos

#### 📖 Resumen
El proceso padre (*main process*) corre como `root` para abrir los puertos 80/443, mientras que los procesos hijos (*workers*) corren como `www-data` (Debian) o `apache` (CentOS). Los directorios de configuración deben tener permisos `755` y los ficheros `644`.

#### 🛠️ Ejercicio y ✅ Verificación
```bash
# 1. Verificar usuarios de los procesos (Debian: apache2 / CentOS: httpd)
ps aux | grep -E "apache2|httpd"

# 2. Detectar archivos y directorios con permisos inseguros
find /etc/apache2 /etc/httpd -type f -not -perm 644 2>/dev/null
find /etc/apache2 /etc/httpd -type d -not -perm 755 2>/dev/null

# 3. Corregir permisos (excluye enlaces simbólicos automáticamente)
find /etc/apache2 /etc/httpd -type d -exec chmod 755 {} \; 2>/dev/null
find /etc/apache2 /etc/httpd -type f -exec chmod 644 {} \; 2>/dev/null
```

---

### 3.2 Control de Acceso por IP, Subred, `.htaccess` y `htpasswd`

#### 📖 Resumen
* **`mod_authz_host`:** Usa `Require ip` (reemplazando las directivas obsoletas `Order`, `Allow`, `Deny` de `mod_access_compat`).
* **`htpasswd`:** Gestiona usuarios de autenticación básica. La bandera `-B` cifra con **bcrypt** y `-c` crea el archivo inicial.
* **`.htaccess`:** Permite delegar directivas por directorio según el nivel definido en `AllowOverride` (`AuthConfig`, `FileInfo`, `Indexes`, `Limit`, `Options`, o `All`).

#### 🛠️ Ejercicio Práctico
1. **Crear usuarios con bcrypt (`-B`):**
   ```bash
   # Debian: /etc/apache2/.htpasswd | CentOS: /etc/httpd/.htpasswd
   htpasswd -B -c /etc/apache2/.htpasswd admin_gerencia
   htpasswd -B /etc/apache2/.htpasswd auditor
   ```
2. **Configurar directorios protegidos en el VirtualHost HTTPS:**
   ```apache
   # Restricción estricta por IP y Subred
   <Directory /var/www/hosting-avanzado.intranet/gerencia>
       Require ip 192.168.1.9 192.168.1.25
       # Ejemplo para subred completa: Require ip 192.168.0.0/255.255.255.0
   </Directory>

   # Autenticación Básica con archivo htpasswd
   <Directory /var/www/hosting-avanzado.intranet/privado>
       AuthType Basic
       AuthBasicProvider file
       AuthUserFile /etc/apache2/.htpasswd
       AuthName "Area Restringida - Inicie Sesion"
       Require valid-user
   </Directory>

   # Delegación mediante .htaccess
   <Directory /var/www/hosting-avanzado.intranet/delegado>
       Options Indexes FollowSymLinks
       AllowOverride All
       Require all granted
   </Directory>
   ```
3. **✅ Verificación:**
   ```bash
   # Prueba sin credenciales (debe devolver HTTP 401 Unauthorized)
   curl -k -I https://hosting-avanzado.intranet/privado/

   # Prueba con credenciales válidas (debe devolver HTTP 200 OK)
   curl -k -I -u admin_gerencia:TU_PASSWORD https://hosting-avanzado.intranet/privado/

   # Prueba desde IP no autorizada a /gerencia (debe devolver HTTP 403 Forbidden)
   curl -k -I https://hosting-avanzado.intranet/gerencia/
   ```

---

### 3.3 Hardening de Información y Bloqueo de Método TRACE (XST)

#### 📖 Resumen
* `ServerTokens Prod`: Muestra únicamente `Server: Apache` en la cabecera HTTP, ocultando versión y sistema operativo.
* `ServerSignature Off`: Oculta la firma del servidor en páginas de error (403, 404, 500).
* `TraceEnable Off`: Desactiva el método HTTP `TRACE` para mitigar ataques **Cross-Site Tracing (XST)**.

#### 🛠️ Ejercicio y ✅ Verificación
Añadir en `/etc/apache2/conf-available/security.conf` (Debian) o `/etc/httpd/conf.d/security.conf` (CentOS):
```apache
ServerTokens Prod
ServerSignature Off
TraceEnable Off
```
```bash
systemctl reload apache2 # o httpd
# Verificar cabecera Server (debe decir solo "Server: Apache")
curl -k -I https://hosting-avanzado.intranet/ | grep -i "^Server:"
# Probar ataque TRACE (debe devolver HTTP 405 Method Not Allowed)
curl -k -X TRACE -I https://hosting-avanzado.intranet/
```

---

### 3.4 Mitigación de HTTP Flood con `mod_evasive`

#### 📖 Resumen
`mod_evasive` previene ataques de denegación de servicio en capa de aplicación (**HTTP GET/POST Flood**) bloqueando temporalmente (código HTTP `403 Forbidden`) a las IPs que superen un umbral de peticiones por segundo hacia una misma página o sitio.

#### 🛠️ Instalación y Configuración
* **En Debian 13:**
  ```bash
  apt update && apt install -y libapache2-mod-evasive
  systemctl stop apache2
  a2enmod evasive
  ```
  Editar `/etc/apache2/mods-available/evasive.conf`:
  ```apache
  <IfModule mod_evasive20.c>
      DOSHashTableSize    3097
      DOSPageCount        2
      DOSSiteCount        50
      DOSPageInterval     1
      DOSSiteInterval     1
      DOSBlockingPeriod   50
      DOSWhitelist        127.0.0.1
  </IfModule>
  ```
  Iniciar servicio: `systemctl start apache2`

* **En CentOS 9:**
  ```bash
  dnf install https://pkgs.sysadmins.ws/el9/base/x86_64/raven-release.el9.noarch.rpm
  dnf --enablerepo=raven-modular install -y mod_evasive
  ```
  Editar `/etc/httpd/conf.d/mod_evasive.conf`:
  ```apache
  <IfModule mod_evasive24.c>
      DOSHashTableSize    3097
      DOSPageCount        2
      DOSSiteCount        50
      DOSPageInterval     1
      DOSSiteInterval     1
      DOSBlockingPeriod   50
      DOSWhitelist        127.0.0.1
  </IfModule>
  ```
  Reiniciar servicio: `systemctl restart httpd`

#### ✅ Verificación de Ataque HTTP Flood y Bloqueo
> **Importante:** Para probar el bloqueo desde la propia máquina local, comenta temporalmente la línea `DOSWhitelist 127.0.0.1` y recarga Apache.

1. **Simular ráfaga de peticiones rápidas (más de 2 por segundo a la misma página):**
   ```bash
   # Lanzar 30 peticiones consecutivas
   for i in {1..30}; do
       curl -k -s -o /dev/null -w "Petición $i -> HTTP %{http_code}\n" https://hosting-avanzado.intranet/
   done
   ```
2. **Resultado esperado:**
   * Las primeras 2-3 peticiones devolverán `HTTP 200`.
   * A partir de ahí, `mod_evasive` bloqueará la IP durante 50 segundos devolviendo **`HTTP 403`**.
3. **Verificar el registro del bloqueo en el log del sistema:**
   ```bash
   # Debian 13
   grep -i "mod_evasive" /var/log/syslog /var/log/apache2/error.log 2>/dev/null
   # CentOS 9
   journalctl -u httpd | grep -i "mod_evasive"
   # Salida esperada: mod_evasive[PID]: Blacklisting address 127.0.0.1: possible DoS attack.
   ```
   *(Recuerda volver a habilitar `DOSWhitelist 127.0.0.1` al finalizar la prueba).*

---

### 3.5 Mitigación de Slowloris con `mod_qos` y `mod_reqtimeout`

#### 📖 Resumen
* **Ataque Slowloris:** Abre múltiples conexiones HTTP y envía cabeceras o datos de forma extremadamente lenta para agotar todos los hilos/sockets disponibles del servidor usando muy poco ancho de banda.
* **`mod_qos`:** Limita conexiones persistentes (`KeepAlive`), cantidad de peticiones por conexión (`MaxKeepAliveRequests`) y exige una tasa mínima de transferencia de datos (`QS_SrvMinDataRate`).
* **`mod_reqtimeout`:** Módulo nativo que establece tiempos máximos de espera (`RequestReadTimeout`) para recibir cabeceras y cuerpo HTTP.

#### 🛠️ Instalación y Configuración de `mod_qos` y `mod_reqtimeout`

* **En Debian 13:**
  ```bash
  apt install -y libapache2-mod-qos
  a2enmod qos reqtimeout
  ```
  Editar `/etc/apache2/mods-available/qos.conf`:
  ```apache
  <IfModule qos_module>
      MaxClients 1792
      TimeOut 10
      KeepAlive on
      KeepAliveTimeout 5
      MaxKeepAliveRequests 10
      QS_SrvMaxConnClose 80%
      QS_ClientEntries 100000
      QS_SrvMinDataRate 150 1200 500
  </IfModule>
  ```
  Verificar `/etc/apache2/mods-available/reqtimeout.conf`:
  ```apache
  <IfModule reqtimeout_module>
      RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
  </IfModule>
  ```
  Reiniciar: `systemctl restart apache2`

* **En CentOS 9:**
  *(Nota: `mod_reqtimeout` viene activo por defecto en CentOS 9; si `mod_qos` no está en EPEL, puede compilarse desde fuentes con `apxs -i -c mod_qos.c` tras instalar `httpd-devel openssl-devel pcre-devel`)*.
  Crear `/etc/httpd/conf.d/reqtimeout.conf`:
  ```apache
  <IfModule reqtimeout_module>
      RequestReadTimeout header=10-20,MinRate=500 body=10,MinRate=500
  </IfModule>
  ```
  Reiniciar: `systemctl restart httpd`

#### ✅ Verificación de Protección contra Conexiones Lentas (Slowloris)
1. **Prueba de límite de peticiones en conexión persistente (`MaxKeepAliveRequests 10`):**
   ```bash
   # Realizar peticiones sobre la misma conexión Keep-Alive y observar las cabeceras de conexión
   curl -k -v https://hosting-avanzado.intranet/ https://hosting-avanzado.intranet/ 2>&1 | grep -E "Connection|Keep-Alive"
   ```
2. **Simular un cliente Slowloris enviando cabeceras incompletas lentamente:**
   ```bash
   # Abrir conexión y pausar 25 segundos antes de cerrar la cabecera (violando MinRate=500 y header timeout)
   (echo -e "GET / HTTP/1.1\r\nHost: hosting-avanzado.intranet\r\n"; sleep 25) | openssl s_client -quiet -connect hosting-avanzado.intranet:443
   ```
3. **Resultado esperado:**
   * El servidor cortará la conexión automáticamente al cumplirse el `TimeOut` / `RequestReadTimeout` (devolviendo **`HTTP 408 Request Timeout`** o cerrando el socket) y registrará el evento en `/var/log/apache2/error.log` o `/var/log/httpd/ssl_error_log`.

---

### 3.6 Aislamiento de VirtualHosts con `mod_suexec`

#### 📖 Resumen
`mod_suexec` permite que cada VirtualHost ejecute scripts CGI/PHP bajo su propio usuario y grupo del sistema operativo en lugar del usuario global de Apache (`www-data` o `apache`), evitando que un sitio comprometido acceda a los archivos de otro cliente en el mismo servidor.

#### 🛠️ Configuración y ✅ Verificación
* **Instalación:**
  * **Debian 13:** `apt install -y apache2-suexec-pristine && a2enmod suexec`
  * **CentOS 9:** Incluido en el paquete `httpd` (`/usr/sbin/suexec`).
* **Ejemplo en VirtualHost:**
  ```apache
  <VirtualHost *:80>
      ServerName juan.example.com
      DocumentRoot /var/www/juan
      SuexecUserGroup juan juan
  </VirtualHost>
  ```
* **Verificación:**
  ```bash
  # Comprobar que el módulo está cargado y ver los parámetros compilados de suexec
  apachectl -M | grep suexec
  /usr/lib/apache2/suexec -V 2>/dev/null || /usr/sbin/suexec -V
  ```

---

### 3.7 Cortafuegos de Aplicaciones Web (WAF) con `mod_security`

#### 📖 Resumen
`mod_security` actúa como un **WAF (Web Application Firewall)** inspeccionando cabeceras y cuerpos HTTP en tiempo real mediante reglas (`SecRule Variables Operador Acciones`). Permite bloquear inyecciones SQL, XSS, *Path Traversal* y escáneres automatizados.

#### 🛠️ Instalación y Configuración
* **En Debian 13:**
  ```bash
  apt install -y libapache2-mod-security2
  cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
  sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
  a2enmod security2
  ```
* **En CentOS 9:**
  ```bash
  dnf install -y mod_security
  sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/httpd/conf.d/mod_security.conf
  ```

#### Reglas WAF Personalizadas
Crear `/etc/modsecurity/custom-rules.conf` (Debian) o `/etc/httpd/conf.d/custom-rules.conf` (CentOS):

```apache
# Regla 1 (Doc 03): Bloquear lectura de /etc/group o Path Traversal con HTTP 406
SecRule REQUEST_URI "@rx (etc/group|etc/passwd|\.\./)" \
    "phase:2,deny,log,status:406,id:500005,msg:'Path Traversal bloqueado'"

# Regla 2: Bloquear SQL Injection en parámetros GET/POST con HTTP 403
SecRule ARGS "@rx (?i:(union\s+all\s+select|union\s+select|drop\s+table))" \
    "phase:2,deny,log,status:403,id:500006,msg:'SQL Injection detectado'"

# Regla 3: Bloquear Cross-Site Scripting (XSS) con HTTP 403
SecRule ARGS "@rx (?i:<script[^>]*>)" \
    "phase:2,deny,log,status:403,id:500007,msg:'Ataque XSS detectado'"

# Regla 4: Bloquear escáneres de vulnerabilidades por User-Agent con HTTP 403
SecRule REQUEST_HEADERS:User-Agent "@rx (?i:(nikto|sqlmap|nmap))" \
    "phase:1,deny,log,status:403,id:500008,msg:'Escaner malicioso bloqueado'"
```

#### ✅ Verificación de Todos los Ataques Web con `curl`
Tras reiniciar Apache (`systemctl restart apache2` o `httpd`), ejecuta estas pruebas para confirmar que el WAF bloquea cada vector:

```bash
# 1. Prueba Path Traversal (Debe devolver HTTP 406 Not Acceptable)
curl -k -s -o /dev/null -w "Path Traversal -> HTTP %{http_code}\n" \
  "https://hosting-avanzado.intranet/?archivo=../../etc/group"

# 2. Prueba SQL Injection (Debe devolver HTTP 403 Forbidden)
curl -k -s -o /dev/null -w "SQL Injection  -> HTTP %{http_code}\n" \
  "https://hosting-avanzado.intranet/?id=1%20UNION%20SELECT%201,2,3"

# 3. Prueba XSS (Debe devolver HTTP 403 Forbidden)
curl -k -s -o /dev/null -w "XSS Attack     -> HTTP %{http_code}\n" \
  "https://hosting-avanzado.intranet/?nombre=<script>alert(1)</script>"

# 4. Prueba Escáner Malicioso (Debe devolver HTTP 403 Forbidden)
curl -k -s -o /dev/null -w "Scanner Nikto  -> HTTP %{http_code}\n" \
  -A "Mozilla/5.0 (Nikto/2.1.6)" "https://hosting-avanzado.intranet/"

# 5. Revisar los registros de auditoría de ModSecurity
grep -E "500005|500006|500007|500008" /var/log/apache2/error.log /var/log/httpd/ssl_error_log 2>/dev/null
```
