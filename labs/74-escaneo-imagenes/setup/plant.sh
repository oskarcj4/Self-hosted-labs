#!/usr/bin/env bash
# Lab 74: la imagen de la API se construye sobre una base vieja y arrastra
# muchos CVE, varios CRITICAL. Hay que escanearla y dejarla a 0 CRITICAL.
set -e
mkdir -p /srv/api
cp -r /opt/lab/setup/project/. /srv/api/
chown -R analista:analista /srv/api
cd /srv/api
docker build -q -t inventario-api:local . >/dev/null
docker run --rm inventario-api:local >/dev/null    # arranca bien (de momento)

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-7401.txt <<'EOF'
SEC-7401 · build-01 · la imagen de inventario-api no pasa el gate de seguridad
- El pipeline nuevo escanea las imágenes con Grype y BLOQUEA si hay CVE de
  severidad CRITICAL. inventario-api:local no pasa.
- El proyecto está en /srv/api (Dockerfile + app). La imagen ya construida se
  llama inventario-api:local.
- El escáner (grype) está instalado y con su base de datos cargada EN LOCAL
  (sin necesidad de Internet):
      grype inventario-api:local
      grype inventario-api:local -o json | jq '.matches[].vulnerability.severity' | sort | uniq -c
- Objetivo: inventario-api:local con 0 vulnerabilidades CRITICAL, y que la
  app siga arrancando (docker run --rm inventario-api:local -> "inventario-api ok").
- Pista: mira de qué vienen los CRITICAL (columna del paquete). La mayoría
  son de la imagen BASE. Hay una base de python mantenida ya cargada:
      docker images | grep python
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 74 plantado."
