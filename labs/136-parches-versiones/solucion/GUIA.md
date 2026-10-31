# Resolución guiada · Lab 136

:::piensa Antes de tocar nada
No puedes parchear lo que no sabes que tienes. Primero el inventario: qué
versiones corren, qué actualizaciones hay y qué dependencias de la app tienen
CVEs. Después, deja de anunciar tus versiones al mundo.
:::

## Paso 1 · ¿Qué anuncias?

:::pista Cómo comprobarlo
```bash
curl -sI http://127.0.0.1/
curl -s http://127.0.0.1/info.php | head
```
`Server: nginx/1.x` y `X-Powered-By: PHP/8.x` le ahorran trabajo al atacante.
:::

## Paso 2 · Inventario

**Pregúntate:** ¿por qué hace falta `apt update` antes de contar actualizaciones?

:::pista Cómo comprobarlo
```bash
php -r 'echo PHP_VERSION, "\n";'
nginx -v
sudo apt-get update
apt list --upgradable 2>/dev/null | grep -c 'upgradable from'
```
Escribe `php=`, `nginx=` y `actualizables=` en `~/inventario.txt`.
:::

## Paso 3 · Dependencias de la app

:::pista Cómo hacerlo
```bash
export TRIVY_CACHE_DIR=/var/cache/trivy
trivy fs --skip-db-update --format json -o ~/trivy-app.json /srv/app
trivy fs --skip-db-update --severity CRITICAL,HIGH /srv/app
jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID][0]' ~/trivy-app.json
```
Añade `cve_critica=` al inventario.
:::

## Paso 4 · Deja de anunciar versiones

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^expose_php.*/expose_php = Off/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^\(\s*\)server_tokens on;/\1server_tokens off;/' /etc/nginx/nginx.conf
sudo rm -f /srv/app/public/info.php
sudo systemctl restart php8.2-fpm
sudo nginx -t && sudo systemctl reload nginx
curl -sI http://127.0.0.1/
```
:::

## Cómo actuar en una situación así

- **Ocultar versiones no parchea nada**: sólo quita una pista. El paso importante es actualizar.
- Escanea dependencias en CI (trivy, osv-scanner) y programa `unattended-upgrades` para el sistema.
- `info.php` nunca en producción: revela rutas, módulos y variables de entorno.

## Si te atascas

- trivy intenta descargar la base de datos: falta `--skip-db-update` o `TRIVY_CACHE_DIR`.
- Sigue saliendo `X-Powered-By`: editaste el `php.ini` de CLI, no el de FPM.
