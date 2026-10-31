#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /usr/local/bin
ls -l ; ls -l --time=ctime --full-time
find /usr/local/bin -newer /var/log/deploy/ultimo.log          # nada: mtime falsificado
find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f # backup-sync, rotate-logs
: > /home/analista/fechas.txt
for f in $(find /usr/local/bin -cnewer /var/log/deploy/ultimo.log -type f); do
  echo "$f  ctime=$(stat -c %z "$f")  mtime=$(stat -c %y "$f")" >> /home/analista/fechas.txt
done
chown analista:analista /home/analista/fechas.txt
mkdir -p /root/cuarentena && mv /usr/local/bin/backup-sync /root/cuarentena/
tar -C /tmp -xzf /var/backups/usr-local-bin.tar.gz bin/rotate-logs
install -m 0755 /tmp/bin/rotate-logs /usr/local/bin/rotate-logs
