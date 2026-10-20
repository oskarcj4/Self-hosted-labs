#!/usr/bin/env bash
# Lab 37 (Día 14): un script que cron ejecuta como root llama a comandos sin
# ruta, y el PATH de cron empieza por una carpeta escribible por todos.
set -e
install -d -m 0755 /etc/app
cat > /etc/app/app.conf <<'EOF'
listen=0.0.0.0:8080
db=postgres://app@db-01/app
workers=4
EOF
echo "feature_x=on" > /etc/app/features.conf

install -d -m 0777 /opt/tools /opt/tools/bin
cat > /opt/tools/bin/s3sync <<'EOF'
#!/bin/sh
# Herramienta interna de sincronización (placeholder)
echo "s3sync: nada que sincronizar"
EOF
chmod 0777 /opt/tools/bin/s3sync

cat > /usr/local/sbin/backup-config.sh <<'EOF'
#!/bin/bash
# Copia de seguridad diaria de /etc/app (cron: /etc/cron.d/backup-config)
set -e
DEST=/var/backups/config
mkdir -p "$DEST"
STAMP=$(date +%Y%m%d-%H%M%S)
tar -cf - -C /etc app | gzip > "$DEST/config-$STAMP.tar.gz"
sha256sum "$DEST/config-$STAMP.tar.gz" > "$DEST/config-$STAMP.tar.gz.sha256"
echo "backup ok: $DEST/config-$STAMP.tar.gz"
EOF
chmod 0755 /usr/local/sbin/backup-config.sh

cat > /etc/cron.d/backup-config <<'EOF'
# Copia diaria de la configuración de la app
PATH=/opt/tools/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
0 2 * * * root backup-config.sh >> /var/log/backup-config.log 2>&1
EOF
chmod 0644 /etc/cron.d/backup-config
systemctl enable --now cron
echo "Lab 37 plantado."
