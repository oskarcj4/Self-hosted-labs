#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
export TRIVY_CACHE_DIR=/var/cache/trivy
H=/home/analista
curl -sI http://127.0.0.1/
php -v; nginx -v
apt-get update -qq
N=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable from' || true)
trivy fs --skip-db-update --format json -o $H/trivy-app.json /srv/app
trivy fs --skip-db-update --severity CRITICAL,HIGH /srv/app || true
C=$(jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID][0]' $H/trivy-app.json)
printf 'php=%s\nnginx=%s\nactualizables=%s\ncve_critica=%s\n' "$(php -r 'echo PHP_VERSION;')" \
  "$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" "$N" "$C" > $H/inventario.txt
chown analista:analista $H/inventario.txt $H/trivy-app.json
sed -i 's/^expose_php.*/expose_php = Off/' /etc/php/8.2/fpm/php.ini
sed -i 's/^\(\s*\)server_tokens on;/\1server_tokens off;/' /etc/nginx/nginx.conf
rm -f /srv/app/public/info.php
systemctl restart php8.2-fpm
nginx -t && systemctl reload nginx && sleep 1
curl -sI http://127.0.0.1/
