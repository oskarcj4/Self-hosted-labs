#!/usr/bin/env bash
# Lab 30 (Día 07): la carpeta de subidas (y sus subcarpetas) es 0777 porque
# "la app no podía escribir". La app corre como www-data.
set -e
install -d -m 0755 /opt/media
install -m 0755 /opt/lab/setup/media.py /opt/media/media.py
U=/var/www/media/uploads
mkdir -p "$U/avatars" "$U/docs"
echo "PNG-avatar-1001" > "$U/avatars/u1001.png"
echo "PNG-avatar-1002" > "$U/avatars/u1002.png"
echo "%PDF factura 0001" > "$U/docs/factura-0001.pdf"
chown -R root:root /var/www/media
chmod 0755 /var/www/media
chmod -R 0777 "$U"
find "$U" -type f -exec chmod 0666 {} +

cat > /etc/systemd/system/media-app.service <<'EOF'
[Unit]
Description=media-app (subidas de usuarios)
After=network.target

[Service]
User=www-data
Group=www-data
ExecStart=/usr/bin/python3 /opt/media/media.py
Restart=always

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now media-app
echo "Lab 30 plantado."
