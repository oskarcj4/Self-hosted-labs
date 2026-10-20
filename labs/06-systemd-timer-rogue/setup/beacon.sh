#!/usr/bin/env bash
# "Beacon" inofensivo del atacante: sólo deja una marca en un log. En un ataque
# real aquí se reabriría una conexión. Lo relanza el timer cada minuto.
echo "sys-health beacon up $(date)" >> /var/log/.sys-health 2>/dev/null || true
