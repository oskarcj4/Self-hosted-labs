#!/usr/bin/env bash
# Lab 25 (Día 02): la tienda se sirve en :80, pero una prueba de compatibilidad
# dejó nginx escuchando también en :8080 (en DOS sitios de la configuración).
set -e
W=/var/www/shop
mkdir -p "$W/css"
cat > "$W/index.html" <<'EOF'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Tienda Norte</title>
<link rel="stylesheet" href="/css/style.css"></head>
<body><h1>Tienda Norte</h1><p>Catálogo de otoño disponible.</p></body></html>
EOF
echo 'body{font-family:sans-serif}' > "$W/css/style.css"

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/shop <<'EOF'
server {
    listen 80 default_server;
    listen 8080;   # compat: clientes legacy (INC-1876)
    server_name _;
    root /var/www/shop;
    index index.html;

    location = /health { return 200 "ok\n"; }
}
EOF
cat > /etc/nginx/sites-available/compat-test <<'EOF'
# Prueba de compatibilidad con la app móvil v1. RETIRAR tras el 15/09.
server {
    listen 8080 default_server;
    server_name compat.local;
    root /var/www/shop;
    add_header X-Compat-Test "1";
}
EOF
ln -sf /etc/nginx/sites-available/shop /etc/nginx/sites-enabled/shop
ln -sf /etc/nginx/sites-available/compat-test /etc/nginx/sites-enabled/compat-test
nginx -t
systemctl enable --now nginx
echo "Lab 25 plantado."
