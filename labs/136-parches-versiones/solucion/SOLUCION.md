# Solución — Parches: inventario, trivy y versiones

## Qué pasaba

- nginx y PHP anunciaban su versión (`server_tokens on`, `expose_php = On`).
- `info.php` publicado.
- La app incluía una versión de PHPMailer con CVEs críticos.
- Nadie había hecho inventario ni `apt update` en meses.

## Arreglo

```bash
export TRIVY_CACHE_DIR=/var/cache/trivy
sudo apt-get update -qq
N=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable from')
trivy fs --skip-db-update --format json -o ~/trivy-app.json /srv/app
C=$(jq -r '[.Results[]?.Vulnerabilities[]? | select(.Severity=="CRITICAL") | .VulnerabilityID][0]' ~/trivy-app.json)
printf 'php=%s\nnginx=%s\nactualizables=%s\ncve_critica=%s\n' "$(php -r 'echo PHP_VERSION;')" \
  "$(nginx -v 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')" "$N" "$C" > ~/inventario.txt

sudo sed -i 's/^expose_php.*/expose_php = Off/' /etc/php/8.2/fpm/php.ini
sudo sed -i 's/^\(\s*\)server_tokens on;/\1server_tokens off;/' /etc/nginx/nginx.conf
sudo rm -f /srv/app/public/info.php
sudo systemctl restart php8.2-fpm
sudo nginx -t && sudo systemctl reload nginx
curl -sI http://127.0.0.1/
bash /opt/lab/check.sh
```

## Más allá del lab

- Actualiza PHPMailer (`composer update phpmailer/phpmailer`) y aplica `apt upgrade` en una ventana.
- Automatiza: `unattended-upgrades` para seguridad, Dependabot/Renovate para dependencias.
