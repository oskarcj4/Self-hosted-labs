#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /srv/shop
ln -s releases/2026-10-12_1105-r42 current.tmp
mv -T current.tmp current
systemctl restart shop
sleep 1
curl -s http://127.0.0.1:8500/health
