#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
chown root:billing /etc/billing/secret.key
chmod 0640 /etc/billing/secret.key
chmod 0755 /etc/billing
