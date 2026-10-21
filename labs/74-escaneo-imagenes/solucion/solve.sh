#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre dentro del lab 74.
set -e
export GRYPE_DB_CACHE_DIR=/opt/grype/db GRYPE_DB_AUTO_UPDATE=false GRYPE_DB_VALIDATE_AGE=false
cd /srv/api
echo "== antes =="
grype -q inventario-api:local -o json | jq '[.matches[].vulnerability.severity]
  | group_by(.) | map({(.[0]): length}) | add'
# La mayoría de los CRITICAL vienen de la base vieja. A la base mantenida.
sed -i 's#^FROM python:3.12.0-alpine3.18#FROM python:3.12-alpine#' Dockerfile
docker build -q -t inventario-api:local . >/dev/null
echo "== después =="
grype -q inventario-api:local -o json | jq '[.matches[].vulnerability.severity]
  | group_by(.) | map({(.[0]): length}) | add'
docker run --rm inventario-api:local
