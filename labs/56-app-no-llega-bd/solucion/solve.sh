#!/usr/bin/env bash
# Solución automática, parte app-01 (sirve para probar el lab). Corre como root.
# La parte de db-01 está en solve-db.sh.
# /etc/hosts es un bind mount de Docker: sed -i no puede reemplazarlo; se
# reescribe su contenido en el sitio.
sed 's/^10\.76\.56\.99\([[:space:]]\+db\.interno\)/10.76.56.20\1/' /etc/hosts > /tmp/hosts.new
cat /tmp/hosts.new > /etc/hosts
getent hosts db.interno
