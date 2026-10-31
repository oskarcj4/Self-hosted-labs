#!/usr/bin/env bash
# Lab 133: la web publica .env y .git, no manda cabeceras de seguridad y la
# cookie de sesión va sin flags.
set -e
W=/var/www/tienda
mkdir -p $W/.git/refs/heads $W/.well-known $W/static
echo '<h1>Tienda 133</h1><script src="/static/app.js"></script>' > $W/index.html
echo 'console.log("ok");' > $W/static/app.js
printf 'DB_HOST=db.interna\nDB_USER=tienda\nDB_PASSWORD=Pr0d-Tienda-133!\nSTRIPE_KEY=sk_live_LAB-133-de-pruebas\n' > $W/.env
cp $W/.env $W/.env.bak
echo 'ref: refs/heads/main' > $W/.git/HEAD
printf '[core]\n\trepositoryformatversion = 0\n[remote "origin"]\n\turl = https://deploy:ghp_LAB-133-de-pruebas@git.empresa.lab/tienda.git\n' > $W/.git/config
printf 'Contact: mailto:seguridad@empresa.lab\nExpires: 2027-12-31T23:59:59Z\n' > $W/.well-known/security.txt

mkdir -p /opt/sesiones
cat > /opt/sesiones/app.py <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Set-Cookie", "sesion=7f3a9c1e5b; Path=/")
        self.end_headers()
        self.wfile.write("Sesión iniciada\n".encode())
    def log_message(self, *a):
        pass
HTTPServer(("127.0.0.1", 9133), H).serve_forever()
PY
cat > /etc/systemd/system/sesiones.service <<'U'
[Unit]
Description=Backend de sesiones de la tienda
[Service]
ExecStart=/usr/bin/python3 /opt/sesiones/app.py
Restart=always
[Install]
WantedBy=multi-user.target
U

cat > /etc/nginx/sites-available/tienda <<'N'
server {
    listen 80 default_server;
    server_name tienda.lab;
    root /var/www/tienda;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }

    location /cuenta/ {
        proxy_pass http://127.0.0.1:9133/;
    }
}
N
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/tienda /etc/nginx/sites-enabled/tienda
echo '127.0.0.1 tienda.lab' >> /etc/hosts
systemctl daemon-reload
systemctl enable --now sesiones nginx

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-133.txt <<'TXT'
SEC-133 · web-133 · informe de pentest
1. http://tienda.lab/.env y /.git/config se pueden descargar (credenciales).
2. Faltan cabeceras de seguridad: X-Frame-Options, Content-Security-Policy,
   X-Content-Type-Options. Deben salir en TODAS las respuestas, también en errores.
3. La cookie de /cuenta/login no lleva HttpOnly, Secure ni SameSite.
4. No romper: la web, /static/, /cuenta/ y /.well-known/security.txt.
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 133 plantado."
