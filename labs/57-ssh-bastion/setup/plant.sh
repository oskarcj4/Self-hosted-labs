#!/usr/bin/env bash
# Lab 57 (dev-01): hay que llegar a app-02, que sólo es alcanzable a través del
# bastión, con claves y sin contraseñas.
set -e
mkdir -p /home/analista/ticket
cat > /home/analista/ticket/TAREA-118.txt <<'EOF'
TAREA-118 · Acceso de despliegue a app-02

Red:
  dev-01  (tú)       10.76.57.10        red DMZ
  bastion            10.76.57.5         DMZ + interna (10.77.57.5)
  app-02             10.77.57.20        sólo red interna

Cuentas (contraseña provisional, sólo para instalar tu clave):
  deploy@bastion   Bastion-2026
  deploy@app-02    App02-2026

Queremos que el pipeline pueda hacer, sin preguntar nada:
  ssh app-02 'comando'
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 57 plantado."
