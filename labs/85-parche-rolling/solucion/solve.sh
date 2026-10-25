#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cp -a /opt/shop/releases/1.2.0/. /srv/app-a/
systemctl restart shop-a
sleep 1
cp -a /opt/shop/releases/1.2.0/. /srv/app-b/
systemctl restart shop-b
sleep 1
