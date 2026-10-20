#!/usr/bin/env bash
# Lab 27 (Día 04): zona de descargas con listado de directorios activado en
# varios niveles (bloque location, sub-location y a nivel http global).
set -e
W=/var/www/files
mkdir -p "$W/downloads/drivers" "$W/downloads/internal" "$W/assets"
cat > "$W/index.html" <<'EOF'
<!doctype html><html lang="es"><head><meta charset="utf-8"><title>Centro de descargas</title></head>
<body><h1>Centro de descargas</h1>
<ul>
  <li><a href="/downloads/manual-usuario.pdf">Manual de usuario</a></li>
  <li><a href="/downloads/release-notes.txt">Notas de versión</a></li>
  <li><a href="/downloads/drivers/driver-v2.bin">Driver v2</a></li>
</ul></body></html>
EOF
echo "%PDF-1.4 manual de usuario (simulado)" > "$W/downloads/manual-usuario.pdf"
echo "v2.4.1 — corrige el bug de sincronización" > "$W/downloads/release-notes.txt"
head -c 2048 /dev/urandom > "$W/downloads/drivers/driver-v2.bin"
echo "precio_mayorista;margen;cliente" > "$W/downloads/internal/precios-mayoristas-2027.csv"
echo "borrador contrato distribuidor" > "$W/downloads/internal/contrato-borrador.txt"
echo "/* estilos */" > "$W/assets/site.css"
echo "logo" > "$W/assets/logo.svg"

rm -f /etc/nginx/sites-enabled/default
# Herencia de un servidor antiguo: listado activado para TODO el servidor.
cat > /etc/nginx/conf.d/00-legacy.conf <<'EOF'
# migrado de files-old-01
autoindex on;
EOF
cat > /etc/nginx/sites-available/files <<'EOF'
server {
    listen 80 default_server;
    server_name _;
    root /var/www/files;
    index index.html;

    location /downloads/ {
        autoindex on;
    }

    location /downloads/drivers/ {
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
}
EOF
ln -sf /etc/nginx/sites-available/files /etc/nginx/sites-enabled/files
nginx -t
systemctl enable --now nginx
echo "Lab 27 plantado."
