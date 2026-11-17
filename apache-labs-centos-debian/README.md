# Laboratorios Prácticos de Apache HTTP Server (CentOS Stream 9 vs Debian 13)

Repositorio de prácticas diseñadas para probar, medir y asegurar servidores web **Apache 2.4** en entornos basados en RHEL (CentOS Stream 9) y Debian (Debian 13 Trixie).

## Inicio Rápido con Docker Compose

1. Clona el repositorio y levanta ambos servidores en paralelo:
   ```bash
   git clone <URL_DE_TU_REPO>
   cd apache-labs-centos-debian
   docker compose up -d --build
   ```

2. Ejecuta el script de preparación inicial en cada contenedor:
   ```bash
   docker exec -it lab-apache-centos9 bash /labs/scripts/setup-centos9.sh
   docker exec -it lab-apache-debian13 bash /labs/scripts/setup-debian13.sh
   ```

3. Ingresa a cualquiera de los dos entornos (todo el repositorio estará montado en `/labs`):
   ```bash
   # Entrar a CentOS Stream 9 (IP: 192.168.56.10 | Puertos host: 8081 / 8441)
   docker exec -it lab-apache-centos9 bash

   # Entrar a Debian 13 (IP: 192.168.56.20 | Puertos host: 8082 / 8442)
   docker exec -it lab-apache-debian13 bash
   ```

## Tabla de Equivalencias Rápidas

| Característica | CentOS Stream 9 (`httpd`) | Debian 13 (`apache2`) |
| :--- | :--- | :--- |
| **Directorio base** | `/etc/httpd/` | `/etc/apache2/` |
| **Configuración principal** | `/etc/httpd/conf/httpd.conf` | `/etc/apache2/apache2.conf` |
| **Módulos** | `/etc/httpd/conf.modules.d/` | `/etc/apache2/mods-available/` |
| **VirtualHosts** | `/etc/httpd/conf.d/*.conf` | `/etc/apache2/sites-available/*.conf` |
| **Gestión de módulos** | Editar `.conf` en `conf.modules.d/` | `a2enmod` / `a2dismod` |
| **Gestión de sitios** | Crear/borrar `.conf` en `conf.d/` | `a2ensite` / `a2dissite` |
| **Usuario del servicio** | `apache` | `www-data` |
| **Logs por defecto** | `/var/log/httpd/` | `/var/log/apache2/` |
| **Validar sintaxis** | `httpd -t` | `apache2ctl -t` |
| **Ver VirtualHosts activos** | `httpd -S` | `apache2ctl -S` |
| **Herramienta `ab`** | Paquete `httpd-tools` | Paquete `apache2-utils` |

## Índice de Laboratorios
1. [Lab 01: MPM (Prefork, Worker, Event) y Benchmarking](./lab01-mpm-benchmark/README.md)
2. [Lab 02: VirtualHosts (Name-Based e IP-Based)](./lab02-virtualhosts/README.md)
3. [Lab 03: Certificados SSL/TLS y SNI Múltiple](./lab03-ssl-sni/README.md)
4. [Lab 04: Hardening y Módulos de Seguridad](./lab04-hardening-security/README.md)

