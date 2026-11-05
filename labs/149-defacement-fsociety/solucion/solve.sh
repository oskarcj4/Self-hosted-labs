#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
WEB=/var/www/html/index.html
CONF=/etc/aide/aide-www.conf

# 1) Restaurar desde el respaldo bueno
cp /opt/backups/index.html.orig "$WEB"
systemctl reload nginx || true

# 2) Línea base de AIDE (DESPUÉS de restaurar)
aide --init -c "$CONF"
cp -f /var/lib/aide/aide.db.new /var/lib/aide/aide.db
aide --check -c "$CONF" >/dev/null 2>&1 && echo "AIDE limpio"

# 3) Hallazgos
cat > $H/hallazgos.txt <<'HAL'
pagina_afectada=/var/www/html/index.html
firma_defacement=fsociety
HAL
chown analista:analista $H/hallazgos.txt

# 4) Vigilancia en tiempo real con inotify (formato por defecto: sin %, salida a fichero)
cat > /etc/systemd/system/fim-www.service <<'U'
[Unit]
Description=FIM del webroot (inotify)
After=multi-user.target
[Service]
ExecStart=/usr/bin/inotifywait -m -r -e modify,create,delete,move -o /var/log/fim.log /var/www/html
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now fim-www.service
echo "solve.sh completado."
