#!/usr/bin/env bash
# Lab 127: tienda.lab responde con varios códigos HTTP; la API de pedidos da
# 502 porque nginx apunta al puerto equivocado del backend.
set -e
echo '127.0.0.1 tienda.lab' >> /etc/hosts
mkdir -p /var/www/tienda /opt/pedidos-api
echo '<h1>Tienda</h1>' > /var/www/tienda/index.html
echo '<h1>Productos</h1>' > /var/www/tienda/productos.html
printf 'admin:%s\n' "$(openssl passwd -apr1 'NoLaAdivinas-127' 2>/dev/null || echo 'x')" > /etc/nginx/.htpasswd-127

cat > /opt/pedidos-api/app.py <<'PY'
import json, time
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        time.sleep(1.2)          # consulta "pesada" a la base de datos
        body = json.dumps({"pedidos": [{"id": 1, "total": 42.5}, {"id": 2, "total": 13.0}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def log_message(self, *a):
        pass
HTTPServer(("127.0.0.1", 8081), H).serve_forever()
PY
cat > /etc/systemd/system/pedidos-api.service <<'U'
[Unit]
Description=API de pedidos de la tienda
[Service]
ExecStart=/usr/bin/python3 /opt/pedidos-api/app.py
Restart=always
[Install]
WantedBy=multi-user.target
U

cat > /etc/nginx/sites-available/tienda <<'N'
upstream pedidos {
    server 127.0.0.1:8001;     # API de pedidos
}
server {
    listen 80;
    server_name tienda.lab;
    root /var/www/tienda;

    location = /            { try_files /index.html =404; }
    location = /productos   { try_files /productos.html =404; }
    location = /catalogo    { return 301 /productos; }
    location /admin         { deny all; }
    location /interno {
        auth_basic "Zona interna";
        auth_basic_user_file /etc/nginx/.htpasswd-127;
    }
    location /api/pedidos   { proxy_pass http://pedidos; }
}
N
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tienda /etc/nginx/sites-enabled/tienda
systemctl daemon-reload
systemctl enable --now pedidos-api nginx

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/WEB-127.txt <<'TXT'
WEB-127 · tienda-127
"La app móvil no carga los pedidos" y el equipo de front pide saber qué
devuelve exactamente cada ruta de http://tienda.lab. Sin navegador: curl.
Rellena ~/codigos.txt con el código HTTP de cada ruta (antes de arreglar nada):
  catalogo=   admin=   interno=   no_existe=   pedidos=
  redireccion=<a dónde manda /catalogo (cabecera Location)>
Arregla /api/pedidos y anota cuánto tarda en empezar a responder:
  ttfb_pedidos=<segundos, de curl -w %{time_starttransfer}>
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 127 plantado."
