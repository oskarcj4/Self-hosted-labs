# Gestión de parches: inventario, escaneo y no anunciar versiones

> Hardening web · php -v · apt list --upgradable · trivy · expose_php

## Escenario

`web-136` sirve una aplicación PHP (`~/ticket/SEC-136.txt`). Antes de
parchear hay que saber qué tienes: no puedes parchear lo que no has
inventariado. Y mientras tanto, no se lo pongas fácil al atacante
anunciando versiones exactas en cada respuesta.

Tres capas que se parchean por separado:

| Capa | Cómo ver qué hay | Cómo ver qué falta |
|---|---|---|
| Sistema (Debian) | `dpkg -l`, `nginx -v`, `php -v` | `apt update && apt list --upgradable` |
| Dependencias de la app | `composer.lock`, `package-lock.json` | `trivy fs <dir>` |
| Imagen de contenedor | la imagen | `trivy image <imagen>` (en tu CI, con Docker) |

## Objetivos

1. Inventario en `~/inventario.txt`: `php=` y `nginx=` (versión exacta) y
   `actualizables=` (paquetes del sistema con actualización pendiente).
2. Escanea `/srv/app` con trivy, guarda el informe JSON en
   `~/trivy-app.json` y anota `cve_critica=` con un CVE CRITICAL.
3. Que las respuestas no lleven `X-Powered-By` ni la versión en `Server`,
   y retira el `info.php` olvidado. La app tiene que seguir funcionando.

## Comandos que te pueden servir

```bash
curl -I http://127.0.0.1/ ; curl -s http://127.0.0.1/info.php | head
php -v ; nginx -v ; php -r 'echo PHP_VERSION;'
sudo apt update ; apt list --upgradable
trivy fs /srv/app
trivy fs --format json -o ~/trivy-app.json /srv/app
jq -r '.Results[].Vulnerabilities[] | "\(.Severity) \(.VulnerabilityID) \(.PkgName) \(.InstalledVersion) -> \(.FixedVersion)"' ~/trivy-app.json
grep -n expose_php /etc/php/8.2/fpm/php.ini ; grep -n server_tokens /etc/nginx/nginx.conf
sudo systemctl restart php8.2-fpm ; sudo nginx -t && sudo systemctl reload nginx
```

> La base de datos de trivy viene precargada en la imagen
> (`TRIVY_SKIP_DB_UPDATE=true`): el lab funciona sin Internet.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
