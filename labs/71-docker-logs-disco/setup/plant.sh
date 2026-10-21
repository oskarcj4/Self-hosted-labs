#!/usr/bin/env bash
# Lab 71: el worker se quedó en DEBUG y su log json-file (sin rotación) se ha
# comido el disco de Docker.
set -e
mkdir -p /srv/pedidos
cp -r /opt/lab/setup/project/. /srv/pedidos/
chown -R analista:analista /srv/pedidos
cd /srv/pedidos
docker compose up -d --quiet-pull
# Espera a que la cola atrasada llene el disco.
for _ in $(seq 1 120); do
  use=$(df -P /var/lib/docker | awk 'NR==2 {print $5+0}')
  [ "$use" -ge 85 ] && break
  sleep 1
done
echo "uso de /var/lib/docker: ${use}%"

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-7111.txt <<'EOF'
INC-7111 · docker-02 · "no space left on device"
- El despliegue de esta mañana ha fallado: Docker se queda sin espacio.
- El jueves pusimos el worker en LOG_LEVEL=DEBUG para depurar una caída.
  Ya está resuelto: tiene que volver a INFO.
- El stack está en /srv/pedidos (docker compose). No borres contenedores
  ni volúmenes a lo loco: es producción.
- Política de logs para contenedores: json-file, como mucho 3 ficheros de
  10 MB por contenedor, y que quede escrito en el compose (versionado).
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 71 plantado."
