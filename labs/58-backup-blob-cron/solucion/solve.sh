#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
mkdir -p /root/.config/rclone
cat > /root/.config/rclone/rclone.conf <<'EOF'
[blob]
type = azureblob
account = devstoreaccount1
key = Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==
endpoint = http://blob-01:10000/devstoreaccount1
EOF
chmod 600 /root/.config/rclone/rclone.conf

cat > /usr/local/bin/backup-app.sh <<'EOF'
#!/bin/bash
# Backup diario de /srv/app/data a blob:backups con retención de 7 días.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG=/var/log/backup-app.log
exec 9>/run/lock/backup-app.lock
if ! flock -n 9; then
  echo "$(date '+%F %T') otra ejecución en marcha; salgo" >> "$LOG"
  exit 1
fi
NAME="app-$(date +%Y%m%d-%H%M).tar.gz"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
log(){ echo "$(date '+%F %T') $*" >> "$LOG"; }

log "inicio $NAME"
tar czf "$TMP/$NAME" -C /srv/app data
tar tzf "$TMP/$NAME" >/dev/null
rclone copyto "$TMP/$NAME" "blob:backups/$NAME"
rclone check "$TMP" blob:backups --one-way --include "$NAME"
rclone delete --min-age 7d blob:backups
log "OK $NAME ($(stat -c %s "$TMP/$NAME") bytes)"
EOF
chmod 700 /usr/local/bin/backup-app.sh
echo '0 3 * * * root /usr/local/bin/backup-app.sh' > /etc/cron.d/backup-app
systemctl enable --now cron
