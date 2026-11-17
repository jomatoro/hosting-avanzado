# Lab 01: Módulos de Multiprocesamiento (MPM) y Benchmarking

## Objetivo
Comparar el rendimiento, latencia y consumo de memoria RAM de Apache bajo los modelos **Prefork**, **Worker** y **Event** utilizando Apache Benchmark (`ab`).

## 1. Instalación de herramientas
* **CentOS 9:** `sudo dnf install -y httpd httpd-tools procps-ng`
* **Debian 13:** `sudo apt update && sudo apt install -y apache2 apache2-utils procps`

## 2. Cambio de MPM

### En CentOS 9
Edita `/etc/httpd/conf.modules.d/00-mpm.conf` y deja **únicamente una** línea descomentada según la prueba:
```apache
# LoadModule mpm_prefork_module modules/mod_mpm_prefork.so
# LoadModule mpm_worker_module modules/mod_mpm_worker.so
LoadModule mpm_event_module modules/mod_mpm_event.so
```
Reinicia el servicio: `sudo systemctl restart httpd`

### En Debian 13
Deshabilita el actual y habilita el deseado (nota: `mpm_prefork` requiere deshabilitar `http2` si estuviera activo):
```bash
sudo a2dismod mpm_event mpm_worker
sudo a2enmod mpm_prefork
sudo systemctl restart apache2
```

## 3. Verificación y Tuning
1. Verifica el MPM cargado:
   * CentOS: `httpd -V | grep -i mpm`
   * Debian: `apache2ctl -V | grep -i mpm`
2. Copia el archivo de ajuste `mpm-tuning.conf` incluido en esta carpeta hacia `/etc/httpd/conf.d/` (CentOS) o `/etc/apache2/conf-available/` + `sudo a2enconf mpm-tuning` (Debian).

## 4. Ejecución de pruebas de carga
Ejecuta el siguiente test para cada uno de los 3 MPM (5000 peticiones, 100 conexiones simultáneas, KeepAlive activo):
```bash
ab -n 5000 -c 100 -k http://127.0.0
```

Mide el consumo de memoria de los procesos Apache durante o justo después de la prueba:
```bash
# CentOS 9
ps -ylC httpd --sort:rss
# Debian 13
ps -ylC apache2 --sort:rss
```

## 5. Tabla de resultados (Completar)

| MPM | Requests/sec | Time per request (ms) | Failed requests | Consumo RAM Total (MB) |
| :--- | :--- | :--- | :--- | :--- |
| **Prefork** | | | | |
| **Worker** | | | | |
| **Event** | | | | |

