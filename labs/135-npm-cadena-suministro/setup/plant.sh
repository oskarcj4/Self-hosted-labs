#!/usr/bin/env bash
# Lab 135: el proyecto depende de un typosquat (color-utilz) con postinstall.
set -e
for _ in $(seq 1 90); do curl -fs http://registry:4873/color-utilz >/dev/null 2>&1 && curl -fs http://registry:4873/fecha-fmt >/dev/null 2>&1 && break; sleep 2; done
A=/srv/app
mkdir -p $A
cat > $A/package.json <<'J'
{
  "name": "panel-ventas",
  "version": "0.3.0",
  "private": true,
  "description": "Panel de ventas interno",
  "main": "index.js",
  "dependencies": {
    "color-utilz": "^1.0.2",
    "fecha-fmt": "^1.4.0"
  }
}
J
cat > $A/index.js <<'J'
const { hexToRgb } = require("color-utils");
const { corta } = require("fecha-fmt");
console.log(corta(new Date()), hexToRgb("#336699"));
J
echo 'registry=http://registry:4873/' > $A/.npmrc
chown -R analista:analista $A
# Token de npm del desarrollador: justo lo que un postinstall malicioso busca.
echo '//registry:4873/:_authToken=npm_token_de_analista_lab135' > /home/analista/.npmrc
chown analista:analista /home/analista/.npmrc
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-135.txt <<'TXT'
SEC-135 · build-135 · proyecto /srv/app
Un compañero añadió una dependencia de colores la semana pasada y el
pipeline de build "hace cosas raras". NO ejecutes npm install a ciegas.
1. Antes de instalar, inspecciona cada dependencia en el registro (npm view).
2. ~/npm.txt:  paquete_malicioso=<nombre>  script=<script que se ejecuta al instalar>
               legitimo=<paquete que se quería instalar>
3. Configura el proyecto para que npm no ejecute scripts de instalación.
4. Corrige la dependencia, genera package-lock.json e instala con npm ci.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 135 plantado."
