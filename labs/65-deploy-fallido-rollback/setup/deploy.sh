#!/bin/bash
# deploy.sh — despliegues de shop (equipo plataforma, 2024).
# Layout: /srv/shop/releases/<fecha>_<hora>-rNN, /srv/shop/current -> release activa.
set -e
R=/srv/shop/releases
case "$1" in
  status)
    ls -1 "$R"
    echo "current -> $(readlink /srv/shop/current)"
    ;;
  rollback)
    # Vuelve a la release anterior.
    prev=$(ls -1 "$R" | head -1)
    ln -sfn "$R/$prev" /srv/shop/current
    systemctl restart shop
    echo "rollback hecho: current -> $prev"
    ;;
  *)
    echo "uso: deploy.sh status|rollback" >&2
    exit 2
    ;;
esac
