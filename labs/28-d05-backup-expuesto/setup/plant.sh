#!/usr/bin/env bash
# Lab 28 (Día 05): un backup completo del sitio (con el volcado de la BD)
# quedó dentro del web root, más una copia escondida. Hay un .zip legítimo
# (kit de prensa) que debe seguir publicado.
set -e
W=/var/www/shop
mkdir -p "$W/css" "$W/img" "$W/downloads" "$W/assets/.cache"
cat > "$W/index.html" <<'EOF'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Tienda Sur</title>
<link rel="stylesheet" href="/css/style.css"></head>
<body><img src="/img/logo.svg" alt=""><h1>Tienda Sur</h1>
<p>Prensa: <a href="/downloads/press-kit.zip">descarga el kit de prensa</a>.</p></body></html>
EOF
echo 'h1{color:#222}' > "$W/css/style.css"
echo '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>' > "$W/img/logo.svg"

# Kit de prensa: un .zip legítimo y enlazado desde la portada.
TMP=$(mktemp -d)
echo "Logos y fotos de producto" > "$TMP/LEEME.txt"
( cd "$TMP" && python3 -m zipfile -c "$W/downloads/press-kit.zip" LEEME.txt )

# Backup "olvidado": sitio + volcado de base de datos con credenciales.
mkdir -p "$TMP/site/db"
cp -r "$W/index.html" "$W/css" "$TMP/site/"
cat > "$TMP/site/db/shop.sql" <<'EOF'
-- MySQL dump shop_prod
INSERT INTO users VALUES (1,'admin','$2y$10$Q1ZmY2...hash','admin@tiendasur.example');
-- conexión: mysql://shop_app:Sur-Prod-2026!@db-prod-01/shop
EOF
tar -czf "$W/backup-2026-10-01.tar.gz" -C "$TMP" site
# Copia que alguien dejó "por si acaso" en una carpeta oculta
cp "$W/backup-2026-10-01.tar.gz" "$W/assets/.cache/site-old.tgz"
rm -rf "$TMP"
sha256sum "$W/backup-2026-10-01.tar.gz" | cut -d' ' -f1 > /root/.tclab-backup.sha

# Pista en el log: alguien de fuera ya lo descargó
mkdir -p /var/log/nginx
cat >> /var/log/nginx/access.log <<'EOF'
185.220.101.7 - - [18/Oct/2026:03:12:44 +0000] "GET /backup-2026-10-01.tar.gz HTTP/1.1" 200 1893 "-" "python-requests/2.31"
185.220.101.7 - - [18/Oct/2026:03:12:51 +0000] "GET /assets/.cache/site-old.tgz HTTP/1.1" 200 1893 "-" "python-requests/2.31"
EOF

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/shop <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/shop;
    index index.html;
}
EOF
ln -sf /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
chown -R www-data:www-data "$W"
nginx -t
systemctl enable --now nginx
echo "Lab 28 plantado."
