#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Ejecuta como root; trabaja como analista.
set -e
sudo -u analista bash -s <<'S'
set -e
cd /srv/app
npm view color-utilz scripts author time
npm view color-utils
npm view fecha-fmt scripts
printf 'paquete_malicioso=color-utilz\nscript=postinstall\nlegitimo=color-utils\n' > ~/npm.txt
echo 'ignore-scripts=true' >> .npmrc
npm pkg delete dependencies.color-utilz
npm pkg set 'dependencies.color-utils=^2.1.0'
npm install --package-lock-only
rm -rf node_modules
npm ci
node index.js
npm audit signatures || true
S
