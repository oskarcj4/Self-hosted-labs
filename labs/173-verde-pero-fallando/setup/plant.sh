#!/usr/bin/env bash
# Lab 173: /health responde 200 y el panel está verde, pero los usuarios ven
# /comprar lento y con 503. Tres causas a la vez:
#  1. Fuga de conexiones del pool: el camino de "tarjeta rechazada" no devuelve
#     la conexión; tras unas cuantas, el pool se agota.
#  2. CPU estrangulada: la unidad systemd tiene CPUQuota=5%.
#  3. DNS lento: el primer nameserver de /etc/resolv.conf no responde nunca
#     (timeout de 2 s en cada resolución de pagos.interno).
set -e
H=/home/analista

# --- DNS: un servidor "muerto" y el bueno (dnsmasq) ------------------------------
cat > /usr/local/bin/dns-muerto <<'PY'
#!/usr/bin/env python3
"""Recibe consultas DNS en 127.0.0.2:53 y no responde nunca."""
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
s.bind(("127.0.0.2", 53))
while True:
    s.recvfrom(4096)
PY
chmod 0755 /usr/local/bin/dns-muerto
UPSTREAM=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
cat > /etc/dnsmasq-interno.conf <<C
listen-address=127.0.0.1
bind-interfaces
no-resolv
server=${UPSTREAM:-127.0.0.11}
address=/pagos.interno/127.0.0.1
address=/catalogo.interno/127.0.0.1
C
cat > /etc/systemd/system/dns-muerto.service <<'U'
[Unit]
Description=DNS antiguo (dado de baja, nadie lo apagó del todo)
[Service]
ExecStart=/usr/local/bin/dns-muerto
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /etc/systemd/system/dns-interno.service <<'U'
[Unit]
Description=DNS interno (dnsmasq)
[Service]
ExecStart=/usr/sbin/dnsmasq -k -C /etc/dnsmasq-interno.conf
Restart=always
[Install]
WantedBy=multi-user.target
U
cp /etc/resolv.conf /opt/lab/resolv.conf.docker
cat > /etc/resolv.conf <<'R'
# DNS de la oficina
nameserver 127.0.0.2
nameserver 127.0.0.1
options timeout:2 attempts:1
R

# --- Servicio de pagos -------------------------------------------------------------
cat > /usr/local/bin/pagos <<'PY'
#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        code, body = (402, b"rechazada") if "rechazada" in self.path else (200, b"autorizada")
        self.send_response(code); self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)
    def log_message(self, *a): pass
ThreadingHTTPServer(("127.0.0.1", 8090), H).serve_forever()
PY
chmod 0755 /usr/local/bin/pagos
cat > /etc/systemd/system/pagos.service <<'U'
[Unit]
Description=Pasarela de pagos (simulada)
[Service]
ExecStart=/usr/local/bin/pagos
Restart=always
[Install]
WantedBy=multi-user.target
U

# --- La tienda ---------------------------------------------------------------------
mkdir -p $H/tienda
cat > $H/tienda/app.py <<'PY'
#!/usr/bin/env python3
"""Tienda: /comprar usa una conexión del pool, autoriza el pago y calcula el total."""
import hashlib, threading, urllib.error, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs


class Pool:
    """Pool de conexiones a la base de datos (simulado)."""
    def __init__(self, tam):
        self.libres = threading.Semaphore(tam)
        self.tam = tam
        self.en_uso = 0

    def obtener(self, timeout=1.0):
        if not self.libres.acquire(timeout=timeout):
            raise TimeoutError("pool agotado")
        self.en_uso += 1

    def devolver(self):
        self.en_uso -= 1
        self.libres.release()


POOL = Pool(5)


def calcular_total():
    h = b"pedido"
    for _ in range(20000):
        h = hashlib.sha256(h).digest()
    return 42.50


class H(BaseHTTPRequestHandler):
    def _r(self, code, body):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/health":
            return self._r(200, "ok")
        if url.path == "/pool":
            return self._r(200, f"en_uso={POOL.en_uso} tam={POOL.tam}")
        if url.path != "/comprar":
            return self._r(404, "no existe")
        tarjeta = parse_qs(url.query).get("tarjeta", ["buena"])[0]
        try:
            POOL.obtener()
        except TimeoutError:
            return self._r(503, "pool agotado")
        try:
            urllib.request.urlopen(f"http://pagos.interno:8090/autorizar?tarjeta={tarjeta}", timeout=5)
        except urllib.error.HTTPError as e:
            return self._r(402, f"pago rechazado ({e.code})")
        total = calcular_total()
        POOL.devolver()
        return self._r(200, f"compra ok: {total}")

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
chown -R analista:analista $H/tienda
cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda
After=pagos.service dns-interno.service
[Service]
User=analista
ExecStart=/usr/bin/python3 /home/analista/tienda/app.py
Restart=always
# Límite puesto "temporalmente" en una migración de servidores.
CPUQuota=5%
[Install]
WantedBy=multi-user.target
U
cat > /usr/local/bin/carga-compras <<'SH'
#!/usr/bin/env bash
# Usuarios comprando: 1 de cada 10 con tarjeta rechazada.
i=0
while true; do
  i=$((i + 1)); t=buena
  [ $((i % 10)) -eq 0 ] && t=rechazada
  curl -s -o /dev/null --max-time 10 "http://127.0.0.1:8080/comprar?tarjeta=$t"
  sleep 2
done
SH
chmod 0755 /usr/local/bin/carga-compras
cat > /etc/systemd/system/carga.service <<'U'
[Unit]
Description=Usuarios comprando
After=tienda.service
[Service]
ExecStart=/usr/local/bin/carga-compras
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /usr/local/bin/monitor-verde <<'SH'
#!/usr/bin/env bash
# El "monitor" del equipo: sólo mira /health.
if curl -sf --max-time 3 http://127.0.0.1:8080/health >/dev/null; then
  echo "tienda: VERDE ✅"
else
  echo "tienda: ROJO ❌"
fi
SH
chmod 0755 /usr/local/bin/monitor-verde

systemctl daemon-reload
systemctl enable --now dns-muerto dns-interno pagos tienda carga

cat > $H/TAREA.txt <<'TXT'
TAREA · Verde, pero fallando

El monitor dice verde (monitor-verde), pero soporte recibe quejas: /comprar
va muy lento y a veces devuelve 503 "pool agotado".

  curl -s -w ' %{http_code} %{time_total}s\n' 'localhost:8080/comprar'

Hay TRES causas distintas a la vez. Encuéntralas y arréglalas:
  - la app (~/tienda/app.py)
  - su unidad systemd (/etc/systemd/system/tienda.service)
  - la resolución de nombres del sistema

Escribe ~/causas.txt con una línea por causa (qué y cómo lo viste).
Luego reinicia:  sudo systemctl daemon-reload && sudo systemctl restart tienda

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 173 plantado."
