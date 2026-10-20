#!/usr/bin/env bash
# Lab 38 (Día 15): cron ejecuta como root un script que vive en /var/tmp y
# que cualquiera puede modificar (carpeta y fichero 0777).
set -e
install -d -m 0777 /var/tmp/jobs
cat > /var/tmp/jobs/cleanup-cache.sh <<'EOF'
#!/bin/bash
# Limpia los temporales de la caché de la app (puesto aquí "de momento")
C=/var/cache/app
n=$(find "$C" -maxdepth 1 -name '*.tmp' -type f | wc -l)
find "$C" -maxdepth 1 -name '*.tmp' -type f -delete
echo "$(date '+%F %T') cleanup-cache: borrados $n temporales"
EOF
chmod 0777 /var/tmp/jobs/cleanup-cache.sh

install -d -m 0755 /var/cache/app
for i in 1 2 3; do echo "tmp $i" > /var/cache/app/render-$i.tmp; done
echo "datos" > /var/cache/app/index.dat

cat > /etc/cron.d/cache-cleanup <<'EOF'
# Limpieza de la caché de la app cada 5 minutos
*/5 * * * * root /var/tmp/jobs/cleanup-cache.sh >> /var/log/cache-cleanup.log 2>&1
EOF
chmod 0644 /etc/cron.d/cache-cleanup
systemctl enable --now cron
echo "Lab 38 plantado."
