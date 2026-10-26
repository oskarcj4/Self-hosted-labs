#!/usr/bin/env bash
# Solución del lab 108: restaurar del backup bueno y reconectar la app.
set -e
B=/var/backups/tienda/tienda-2026-10-18.dump

# 1) Elegir un backup VÁLIDO (el de hoy está vacío). pg_restore -l lista su
#    contenido: si falla, el fichero no sirve.
sudo -u postgres pg_restore -l "$B" >/dev/null

# 2) Restaurar en una base nueva (el ROLE 'tienda' sobrevivió al incidente).
sudo -u postgres createdb -O tienda tienda
sudo -u postgres pg_restore -d tienda "$B"

# 3) Reconectar la app: apuntar db.conf a la base buena y reiniciar.
cat > /etc/tienda/db.conf <<'EOF'
host=127.0.0.1 port=5432 dbname=tienda user=tienda password=tienda
EOF
systemctl restart tienda-web

sleep 2
curl -s http://127.0.0.1:8080/health; echo
