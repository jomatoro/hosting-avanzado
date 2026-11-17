# Lab 02: VirtualHosts (Name-Based vs IP-Based)

## Objetivo
Configurar múltiples sitios web en un solo servidor Apache diferenciando el tráfico tanto por **dirección IP** como por **cabecera Host (Nombre de dominio)**.

> **Nota teórica:** En Apache 2.2 existía la directiva `NameVirtualHost *:80`. En **Apache 2.4** esa directiva está obsoleta y no debe usarse; Apache activa el alojamiento basado en nombres automáticamente cuando múltiples bloques `<VirtualHost>` comparten la misma IP y puerto.

## 1. Preparar directorios y páginas de prueba
Ejecuta estos comandos para crear los sitios:
```bash
sudo mkdir -p /var/www/{ip1,ip2,app1,app2}
echo "<h1>Sitio IP 1 (192.168.56.101)</h1>" | sudo tee /var/www/ip1/index.html
echo "<h1>Sitio IP 2 (192.168.56.102)</h1>" | sudo tee /var/www/ip2/index.html
echo "<h1>Sitio Nombre 1 (app1.lab.local)</h1>" | sudo tee /var/www/app1/index.html
echo "<h1>Sitio Nombre 2 (app2.lab.local)</h1>" | sudo tee /var/www/app2/index.html
```

## 2. Configurar IPs secundarias temporales (Para IP-Based)
Reemplaza `eth0` por tu interfaz de red (`ip a`):
```bash
sudo ip addr add 192.168.56.101/24 dev eth0
sudo ip addr add 192.168.56.102/24 dev eth0
```

## 3. Desplegar configuraciones
* **CentOS 9:** Copia `ip-vhosts.conf` y `name-vhosts.conf` en `/etc/httpd/conf.d/` y ejecuta `sudo systemctl reload httpd`.
* **Debian 13:** Copia ambos archivos en `/etc/apache2/sites-available/`, habilítalos con `sudo a2ensite ip-vhosts name-vhosts` y ejecuta `sudo systemctl reload apache2`.

## 4. Validación
1. Revisa el árbol de VirtualHosts y cuál es el sitio por defecto:
   ```bash
   # CentOS 9: httpd -S
   # Debian 13: apache2ctl -S
   ```
2. Prueba los sitios por IP:
   ```bash
   curl http://192.168.56.101
   curl http://192.168.56.102
   ```
3. Prueba los sitios por Nombre simulando la cabecera HTTP `Host`:
   ```bash
   curl -H "Host: app1.lab.local" http://127.0.0.1
   curl -H "Host: app2.lab.local" http://127.0.0.1
   curl -H "Host: desconocido.lab.local" http://127.0.0.1
   ```
   *Pregunta:* ¿Qué sitio responde cuando envías `desconocido.lab.local` y por qué?

