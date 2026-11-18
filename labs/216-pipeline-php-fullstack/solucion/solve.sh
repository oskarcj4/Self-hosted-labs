#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
W=/var/www/reservas

# 1. Antes de NINGÚN despliegue más: sacar los datos y el .env a shared/.
#    (El rsync --delete viejo los borraría.)
sudo mkdir -p $W/shared/data $W/releases
if [ -f $W/data/reservas.sqlite ]; then
  sudo cp -a $W/data/reservas.sqlite $W/shared/data/
else
  sudo cp -a "$(ls -1t /var/backups/reservas-*.sqlite | head -1)" $W/shared/data/reservas.sqlite
fi
NUEVA=$(tr -dc 'A-Za-z0-9' < /dev/urandom | head -c 24)   # la del repo está quemada: rotar
sudo tee $W/shared/.env > /dev/null <<ENV
APP_ENV=produccion
DB_PATH=$W/shared/data/reservas.sqlite
SMTP_USER=reservas@empresa.local
SMTP_PASS=$NUEVA
ENV
sudo chown -R www-data:www-data $W/shared
sudo chmod 640 $W/shared/.env

# 2. Despliegue atómico: release por SHA, shared enlazado, enlace current, recarga de php-fpm.
sudo tee /usr/local/bin/publicar-reservas > /dev/null <<'SH'
#!/usr/bin/env bash
# publicar-reservas DIR SHA — despliegue atómico de reservas.
#   releases/<sha>  código + vendor sin dev      shared/  .env y data/
#   current -> releases/<sha>  (rename atómico)   php-fpm recargado (opcache)
set -euo pipefail
SRC=$1; SHA=$2
W=/var/www/reservas
[[ $SHA =~ ^[0-9a-f]{40}$ ]] || { echo "SHA no válido: $SHA"; exit 2; }
[ -f "$SRC/composer.lock" ] || { echo "no hay composer.lock en $SRC"; exit 2; }
R=$W/releases/$SHA
rm -rf "$R"; mkdir -p "$R"
rsync -a --exclude .git --exclude .github --exclude tests --exclude vendor --exclude .env \
      --exclude phpunit.xml --exclude phpstan.neon "$SRC/" "$R/"
COMPOSER_CACHE_DIR=/opt/composer-cache COMPOSER_DISABLE_NETWORK=1 COMPOSER_ALLOW_SUPERUSER=1 \
  composer install -q -d "$R" --no-dev --optimize-autoloader --no-interaction
echo "$SHA" > "$R/REVISION"
ln -sfn $W/shared/.env "$R/.env"
chown -R root:root "$R"; chmod -R a+rX "$R"
ln -sfn "$R" $W/.current.tmp && mv -T $W/.current.tmp $W/current
systemctl reload php8.2-fpm nginx      # opcache.validate_timestamps=0 (y nginx, por si cambió su config)
ls -1dt $W/releases/*/ | tail -n +6 | xargs -r rm -rf
for _ in $(seq 1 10); do
  curl -fs http://127.0.0.1:8080/api/version | grep -q "$SHA" && { echo "publicado ${SHA:0:8}"; exit 0; }
  sleep 1
done
echo "la versión ${SHA:0:8} no responde"; exit 1
SH

# 3. nginx sirve current/public ($realpath_root ya está: cada petición ve una sola release).
#    Se aplica en el primer despliegue, que recarga nginx cuando current ya existe.
sudo sed -i "s#root /var/www/reservas/public;#root /var/www/reservas/current/public;#" /etc/nginx/sites-available/default
sudo nginx -t -q

# 4. Repo: fuera el .env, arreglo del solape, pipeline con tests y sólo main.
cd ~/reservas
git pull -q
git rm -q --cached .env && rm -f .env
printf 'vendor/\ndata/\n.env\n' > .gitignore
sed -i 's/AND desde <= ? AND hasta >= ?/AND desde < ? AND hasta > ?/' src/Reservas.php
cat > .github/workflows/deploy.yml <<'YML'
name: deploy
on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Dependencias (con dev)
        run: composer install --no-interaction --no-progress
      - name: composer validate
        run: composer validate --no-check-publish
      - name: Análisis estático
        run: vendor/bin/phpstan analyse --no-progress
      - name: Tests
        run: vendor/bin/phpunit

  deploy:
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Publicar
        run: sudo /usr/local/bin/publicar-reservas "$PWD" "${{ github.sha }}"
YML
git add -A
git commit -qm "ci: tests, despliegue atómico sólo desde main; .env fuera del repo; fix solape"
git push -q origin main

SHA=$(git rev-parse HEAD)
echo "Esperando al pipeline de ${SHA:0:8}..."
for _ in $(seq 1 180); do
  curl -fs http://127.0.0.1:8080/api/version | grep -q "$SHA" && break
  sleep 2
done
ci-estado
echo "solve.sh completado."
