#!/usr/bin/env bash
# Lab 141: HAProxy con blue (1.4.0, sana) y green (1.5.0, rota) en blue/green.
# El health check mira "/", que green sirve bien aunque el checkout falle.
set -e
mkdir -p /opt/shop
cat > /opt/shop/app.py <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
VERSION, PORT, ROTA = sys.argv[1], int(sys.argv[2]), sys.argv[3] == "rota"
class H(BaseHTTPRequestHandler):
    def _send(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("X-App-Version", VERSION)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)
    def do_GET(self):
        if self.path == "/":
            return self._send(200, {"tienda": "shop", "version": VERSION})
        if self.path == "/health":
            if ROTA:
                return self._send(503, {"status": "fail", "db": "esquema v13, la app espera v14"})
            return self._send(200, {"status": "ok", "db": "esquema v13"})
        if self.path.startswith("/api/checkout"):
            if ROTA:
                return self._send(500, {"error": "column orders.discount_code does not exist"})
            return self._send(200, {"pedido": "ok", "version": VERSION})
        self._send(404, {"error": "no encontrado"})
    def log_message(self, *a):
        pass
ThreadingHTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY
for c in "blue 1.4.0 8001 sana" "green 1.5.0 8002 rota"; do
  set -- $c
  cat > /etc/systemd/system/shop-$1.service <<U
[Unit]
Description=shop $2 ($1)
[Service]
ExecStart=/usr/bin/python3 /opt/shop/app.py $2 $3 $4
Restart=always
[Install]
WantedBy=multi-user.target
U
done

cat > /etc/haproxy/haproxy.cfg <<'CFG'
global
    log /dev/log local0
    stats socket /run/haproxy/admin.sock mode 660 level user
    stats timeout 30s
    user haproxy
    group haproxy

defaults
    log     global
    mode    http
    option  httplog
    timeout connect 2s
    timeout client  30s
    timeout server  30s

frontend web
    bind *:80
    default_backend shop

# blue/green: green es la versión nueva (1.5.0); blue (1.4.0) queda de reserva.
backend shop
    option httpchk GET /
    server green 127.0.0.1:8002 check inter 2s fall 2 rise 2
    server blue  127.0.0.1:8001 check inter 2s fall 2 rise 2 backup
CFG
systemctl daemon-reload
systemctl enable --now shop-blue shop-green haproxy
sleep 3
systemctl show -p MainPID --value haproxy > /opt/lab/.haproxy-pid

H=/home/analista
mkdir -p $H/ticket
cat > $H/ticket/INC-141.txt <<'TXT'
INC-141 · prioridad ALTA · 10:02
Desde el deploy de las 09:55 (shop 1.5.0, slot green) el checkout devuelve 500.
HAProxy sigue mandando todo el tráfico a green: según él, green está "UP".
Acuerdo de nivel de servicio: volver a la versión buena en menos de 2 minutos.

1. Vuelve a blue (1.4.0) YA, sin reiniciar HAProxy (reload sí vale).
2. Arregla el health check para que un green roto salga solo del balanceo.
3. Deja un ~/rollback.sh reutilizable que haga la vuelta a blue en < 2 min.
4. Anota en ~/incidente.txt:
     version_mala=<versión>
     version_buena=<versión>
TXT
chown -R analista:analista $H/ticket
echo "Lab 141 plantado."
