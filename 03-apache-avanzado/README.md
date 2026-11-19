# 🚀 Guía Avanzada de Servidor Web Apache (SSL, Rendimiento y Seguridad)

Este repositorio contiene el resumen teórico y una guía de laboratorios prácticos sobre la administración avanzada de **Apache HTTP Server**, cubriendo certificados SSL/TLS, optimización de rendimiento mediante MPM, autenticación de usuarios, WAF con ModSecurity y endurecimiento (*hardening*).

> **Compatibilidad:** Los ejercicios prácticos y el script de despliegue funcionan tanto en **Debian 13 (Trixie)** (`apache2`) como en **CentOS Stream 9** (`httpd`).

---

## 📑 Índice de Contenidos
1. [Certificados SSL/TLS (Docs 01, 04 y 05)](#1-certificados-ssltls)
2. [Rendimiento y Perfiles Multiproceso - MPM (Docs 02, 06 y 07)](#2-rendimiento-y-perfiles-multiproceso-mpm)
3. [Seguridad, Control de Acceso y WAF (Docs 03, 08 y 09)](#3-seguridad-control-de-acceso-y-waf)
4. [Despliegue Automatizado (Script Bash)](#4-despliegue-automatizado-script-bash)

---

## 1. Certificados SSL/TLS

### 📖 Resumen Teórico
* **SSL/TLS:** Protocolos criptográficos que cifran el tráfico entre cliente y servidor mediante una clave privada secreta y un certificado público X.509.
* **Certificados Autofirmados:** Generados localmente con `openssl`. Cifran el tráfico pero muestran advertencias en el navegador al no estar firmados por una CA pública.
* **Directivas Clave:** `SSLEngine on`, `SSLCertificateFile`, `SSLCertificateKeyFile`, `SSLProtocol` y `Redirect "/" "https://..."`.

### 🛠️ Ejercicio Práctico 1: HTTPS con Certificado Autofirmado

#### Paso 1: Generar clave privada y certificado X.509 (RSA 4096 bits, 3 años)
```bash
mkdir -p /etc/ssl/private /etc/ssl/certs
openssl req -x509 -nodes -days 1095 -newkey rsa:4096 \
  -subj "/C=AR/ST=BuenosAires/L=CABA/O=LabApache/CN=hosting-avanzado.intranet" \
  -keyout /etc/ssl/private/hosting-avanzado.intranet.key \
  -out /etc/ssl/certs/hosting-avanzado.intranet.crt
```

#### Paso 2: Configurar parámetros SSL seguros
* **Debian 13:** `/etc/apache2/conf-available/ssl-params.conf` (activar con `a2enmod ssl headers && a2enconf ssl-params`)
* **CentOS 9:** `/etc/httpd/conf.d/ssl-params.conf` (requiere `dnf install -y mod_ssl`)

```apache
SSLCipherSuite EECDH+AESGCM:EDH+AESGCM:AES256+EECDH:AES256+EDH
SSLProtocol All -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
SSLHonorCipherOrder On
Header always set X-Frame-Options DENY
Header always set X-Content-Type-Options nosniff
SSLCompression off
SSLSessionTickets Off
```

#### Paso 3: Configurar VirtualHost (Redirección HTTP -> HTTPS)
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

---

## 2. Rendimiento y Perfiles Multiproceso (MPM)

### 📖 Resumen Teórico

| Característica | `mpm_prefork` | `mpm_worker` | `mpm_event` |
| :--- | :--- | :--- | :--- |
| **Arquitectura** | Un proceso hijo por conexión (sin hilos). | Procesos hijos con múltiples **hilos**. | Similar a `worker`, con hilo dedicado a *Keep-Alive*. |
| **Consumo RAM** | Alto. | Bajo. | Muy bajo y altamente escalable. |
| **Uso Ideal** | Bibliotecas no *thread-safe* (`mod_php` clásico). | Contenido estático y concurrencia media. | Alto tráfico simultáneo y PHP-FPM. |

### 🛠️ Ejercicio Práctico 2: Tuning de `mpm_event` y Benchmark con `ab`
1. **Activar `mpm_event`:**
   * **Debian 13:** `a2dismod mpm_prefork mpm_worker && a2enmod mpm_event`
   * **CentOS 9:** Editar `/etc/httpd/conf.modules.d/00-mpm.conf` dejando activo únicamente `LoadModule mpm_event_module modules/mod_mpm_event.so`.
2. **Parámetros recomendados:**
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
3. **Ejecutar prueba de carga:**
   ```bash
   ab -k -n 1000 -c 100 -H 'Accept-Encoding: gzip,deflate' https://hosting-avanzado.intranet/
   ```

---

## 3. Seguridad, Control de Acceso y WAF

### 📖 Resumen Teórico
* **Procesos y Permisos:** El proceso maestro corre como `root` y los procesos hijos como `www-data` (Debian) o `apache` (CentOS). Directorios de configuración en `755` y archivos en `644`.
* **Autorización (`mod_authz_host`) y Autenticación (`htpasswd`):** Uso de `Require ip` para listas blancas de red y `AuthType Basic` con cifrado `bcrypt` (`-B`) para proteger directorios sensibles.
* **Mitigación DDoS / Slowloris:** `mod_evasive` (bloqueo temporal por exceso de peticiones) y `mod_qos` / `mod_reqtimeout` (control de conexiones persistentes y tasas mínimas de transferencia).
* **WAF (`mod_security`):** Cortafuegos de aplicaciones web que inspecciona cabeceras y cuerpos HTTP en tiempo real mediante reglas (`SecRule Variables Operador Acciones`).

### 🛠️ Ejercicio Práctico 3A: Control de Acceso por IP y Autenticación Básica (`htpasswd`)

#### Paso 1: Crear usuarios con cifrado bcrypt (`-B`)
* **Debian 13:** Archivo en `/etc/apache2/.htpasswd`
* **CentOS 9:** Archivo en `/etc/httpd/.htpasswd`

```bash
# Primer usuario (-c crea el archivo, -B fuerza cifrado bcrypt)
htpasswd -B -c /etc/apache2/.htpasswd admin_gerencia

# Usuarios adicionales (SIN la bandera -c para no sobrescribir)
htpasswd -B /etc/apache2/.htpasswd auditor
```

#### Paso 2: Proteger rutas en el VirtualHost HTTPS
* **Ruta `/gerencia` (Restricción estricta por IP):**
  ```apache
  <Directory /var/www/hosting-avanzado.intranet/gerencia>
      Require ip 192.168.1.9 192.168.1.25
  </Directory>
  ```
* **Ruta `/privado` (Autenticación por usuario y contraseña):**
  ```apache
  <Directory /var/www/hosting-avanzado.intranet/privado>
      AuthType Basic
      AuthBasicProvider file
      AuthUserFile /etc/apache2/.htpasswd
      AuthName "Area Restringida - Inicie Sesion"
      Require valid-user
  </Directory>
  ```

### 🛠️ Ejercicio Práctico 3B: Reglas WAF con ModSecurity (`mod_security`)

#### Paso 1: Instalar y habilitar el módulo
* **Debian 13:**
  ```bash
  apt install -y libapache2-mod-security2
  cp /etc/modsecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf
  sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf
  a2enmod security2
  ```
* **CentOS 9:**
  ```bash
  dnf install -y mod_security
  sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/httpd/conf.d/mod_security.conf
  ```

#### Paso 2: Añadir reglas personalizadas de protección
Agrega las siguientes reglas en `/etc/modsecurity/custom-rules.conf` (Debian) o `/etc/httpd/conf.d/custom-rules.conf` (CentOS):

```apache
# 1. Bloquear intentos de Path Traversal / lectura de /etc/passwd o /etc/group
SecRule REQUEST_URI "@rx (etc/passwd|etc/group|\.\./)" \
    "id:500005,phase:2,deny,log,status:406,msg:'Intento de Path Traversal detectado'"

# 2. Bloquear inyección SQL básica en parámetros GET/POST (ej. UNION SELECT)
SecRule ARGS "@rx (?i:(union\s+all\s+select|union\s+select|drop\s+table))" \
    "id:500006,phase:2,deny,log,status:403,msg:'Posible ataque SQL Injection'"

# 3. Bloquear ataques Cross-Site Scripting (XSS) con etiquetas <script>
SecRule ARGS "@rx (?i:<script[^>]*>)" \
    "id:500007,phase:2,deny,log,status:403,msg:'Posible ataque XSS detectado'"

# 4. Bloquear escáneres maliciosos por User-Agent (ej. Nikto, sqlmap)
SecRule REQUEST_HEADERS:User-Agent "@rx (?i:(nikto|sqlmap|nmap))" \
    "id:500008,phase:1,deny,log,status:403,msg:'Escaner de vulnerabilidades bloqueado'"
```

#### Paso 3: Probar las reglas WAF con `curl`
```bash
# Debe devolver HTTP 406 Not Acceptable
curl -k -I "https://hosting-avanzado.intranet"

# Debe devolver HTTP 403 Forbidden
curl -k -I -A "sqlmap/1.7" "https://hosting-avanzado.intranet/"
```

### 🛠️ Ejercicio Práctico 3C: Protección Anti-DDoS (`mod_evasive`)
```apache
<IfModule mod_evasive20.c> # Usar mod_evasive24.c en CentOS 9
    DOSHashTableSize    3097
    DOSPageCount        2
    DOSSiteCount        50
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   50
    DOSWhitelist        127.0.0.1
</IfModule>
```
