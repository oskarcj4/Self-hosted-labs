# Resolución guiada · Lab 136

:::piensa No puedes parchear lo que no sabes que tienes
Antes de actualizar nada hace falta un **inventario**: qué versiones corren,
qué actualizaciones hay pendientes y qué dependencias de la app tienen
vulnerabilidades conocidas. Y mientras parcheas, no le regales al atacante tu
versión exacta en cada respuesta.
:::

**El plan:** (1) ver qué anuncia la web, (2) inventario del sistema,
(3) escaneo de las dependencias de la app y (4) dejar de anunciar versiones.

## Paso 1 · ¿Qué anuncias?

**Objetivo:** ver lo que cualquiera obtiene con una sola petición.

:::pista Cómo hacerlo
```bash
curl -sI http://127.0.0.1/
curl -s http://127.0.0.1/info.php | head
```
`-I` pide sólo las **cabeceras** de la respuesta (método `HEAD`), sin el cuerpo.

**Qué deberías ver:** `Server: nginx/1.22.1` y `X-Powered-By: PHP/8.2.x`, y una
página `phpinfo()` con toda la configuración de PHP. Con la versión exacta, un
atacante busca directamente los CVEs de esa versión.
:::

## Paso 2 · Inventario del sistema

**Objetivo:** las versiones exactas y cuántos paquetes tienen actualización.

**Pregúntate:** ¿cómo sabe `apt` que hay versiones nuevas, si nadie le ha
dicho que mire?

:::pista Cómo hacerlo
```bash
php -r 'echo PHP_VERSION, "\n";'
/usr/sbin/nginx -v
sudo apt-get update
apt list --upgradable 2>/dev/null | grep -c 'upgradable from'
```
- `php -r '…'` ejecuta una línea de PHP. `PHP_VERSION` da la versión limpia
  (`8.2.x`), sin el texto extra de `php -v`.
- `nginx` está en `/usr/sbin`, que en Debian **no** está en el `PATH` de los
  usuarios normales: por eso la ruta completa. `nginx -v` escribe en la salida
  de errores, por eso no se puede filtrar sin `2>&1`.
- `apt list --upgradable` compara lo instalado con los **índices** de paquetes
  que tienes descargados. Si nunca hiciste `apt-get update`, esos índices
  están vacíos o viejos y la lista miente. `2>/dev/null` tira un aviso de que
  esa salida no es estable para scripts.
- `grep -c` cuenta las líneas que contienen el texto.

Escríbelo:
```bash
nano ~/inventario.txt
```
```
php=<versión de php>
nginx=<sólo el número, p. ej. 1.22.1>
actualizables=<el número de grep -c>
```
:::

## Paso 3 · Dependencias de la app

**Objetivo:** saber si las librerías de la app tienen CVEs.

:::pista Cómo hacerlo
Las dependencias de una app PHP las fija `composer.lock`. trivy sabe leerlo:
```bash
trivy fs --skip-db-update --format json -o ~/trivy-app.json /srv/app
trivy fs --skip-db-update --severity CRITICAL,HIGH /srv/app
```
- `trivy fs <carpeta>` busca ficheros de dependencias (`composer.lock`,
  `package-lock.json`…) y compara cada versión con su base de CVEs.
- `--skip-db-update`: usa la base ya descargada (el lab no tiene Internet).
- `--format json -o fichero`: guarda el informe en JSON, para procesarlo.

Saca un CVE crítico del JSON:
```bash
jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID][0]' ~/trivy-app.json
```

| Parte del filtro | Qué hace |
|---|---|
| `.Results[]?` | Recorre cada resultado (uno por fichero analizado). El `?` evita un error si no hay. |
| `.Vulnerabilities[]?` | Recorre las vulnerabilidades de cada resultado. |
| `select(.Severity=="CRITICAL")` | Se queda sólo con las críticas. |
| `.VulnerabilityID` | De cada una, el identificador (`CVE-…`). |
| `[ … ][0]` | Mete todos en una lista y toma el primero. `-r` lo imprime sin comillas. |

Añade `cve_critica=<ese CVE>` a `~/inventario.txt`.
:::

## Paso 4 · Deja de anunciar versiones

**Objetivo:** que las cabeceras no digan versiones y que `info.php`
desaparezca, sin romper la app.

:::pista Cómo hacerlo
```bash
sudo sed -i 's/^expose_php.*/expose_php = Off/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^\(\s*\)server_tokens on;/\1server_tokens off;/' /etc/nginx/nginx.conf
sudo rm -f /srv/app/public/info.php
sudo systemctl restart php8.2-fpm
sudo nginx -t && sudo systemctl reload nginx
curl -sI http://127.0.0.1/
```
- `sed -i 's/A/B/'` sustituye en el propio fichero. `^expose_php.*` es "la
  línea que empieza por `expose_php`, entera".
- En el segundo, `\(\s*\)` captura los espacios del principio y `\1` los vuelve
  a poner: la línea conserva su sangría.
- `expose_php` controla la cabecera `X-Powered-By`. Hay **dos** `php.ini`: el de
  `cli/` (la terminal) y el de `fpm/` (el que sirve la web). Es el de FPM.
- `server_tokens off` hace que nginx diga `Server: nginx` sin versión.

**Qué deberías ver:** `Server: nginx` sin número y ninguna línea
`X-Powered-By`. Comprueba que la app sigue viva y valida:
```bash
curl -s http://127.0.0.1/
bash /opt/lab/check.sh
```
:::

## Cómo actuar en una situación así

- **Ocultar versiones no parchea nada:** sólo quita una pista. El paso
  importante es actualizar (`composer update phpmailer/phpmailer`,
  `apt upgrade` en una ventana de mantenimiento).
- Automatiza: `unattended-upgrades` para el sistema; Dependabot o Renovate para
  las dependencias; trivy en el pipeline.
- `info.php` nunca en producción: revela rutas, módulos y variables.

## Si te atascas

- **`nginx: command not found`:** usa `/usr/sbin/nginx -v` (o `sudo nginx -v`).
- **trivy intenta descargar la base de datos:** falta `--skip-db-update`.
- **Sigue saliendo `X-Powered-By`:** editaste el `php.ini` de CLI, o no
  reiniciaste `php8.2-fpm`.
- **`actualizables=` no coincide:** el número cambia después de cada
  `apt-get update`. Vuelve a contarlo justo antes de validar.
