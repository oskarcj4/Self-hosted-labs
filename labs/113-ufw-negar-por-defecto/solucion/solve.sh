#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
ufw status numbered || true
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH          # primero SSH: si no, en un servidor real te quedas fuera
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status verbose
sleep 35                   # espera a que el escáner externo pase de nuevo
