#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
N=$(find /srv/datos -type f -name '*.lock' | wc -l)
echo "alterados=$N" > /home/analista/incidente.txt
chown analista:analista /home/analista/incidente.txt
# Quién escribe: inotifywait enseña la actividad, lsof/ps el proceso.
timeout 25 inotifywait -m -r -e create,delete /srv/datos 2>/dev/null | head -3 || true
ps aux | grep -v grep | grep -i indexer || true
systemctl disable --now datos-indexer
mkdir -p /root/evidencia && cp /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service /root/evidencia/
rm -f /usr/local/sbin/datos-indexer /etc/systemd/system/datos-indexer.service
systemctl daemon-reload
mkdir -p /mnt/respaldo
mount -o ro,loop /var/backups/respaldo-offline.img /mnt/respaldo
(cd /mnt/respaldo/datos && sha256sum -c --quiet ../SHA256SUMS)    # el respaldo está sano
rsync -a --delete /mnt/respaldo/datos/ /srv/datos/
(cd /srv/datos && sha256sum -c --quiet /mnt/respaldo/SHA256SUMS) && echo "Restauración verificada"
umount /mnt/respaldo
