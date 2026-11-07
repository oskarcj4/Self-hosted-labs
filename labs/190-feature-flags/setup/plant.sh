#!/usr/bin/env bash
# Lab 190: "feature flags" a base de variables de entorno: todo o nada, hace
# falta reiniciar para cambiarlas, el 20 % es aleatorio en cada petición y
# hay un flag muerto de 2023 con su código.
set -e
A=/home/analista/tienda
mkdir -p $A /etc/tienda /opt/lab/tests

cat > $A/app.py <<'PY'
"""Tienda: GET /checkout?usuario=ID -> qué checkout ve ese usuario."""
import json, os, random
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

# Flags "de toda la vida": variables de entorno de la unidad.
NUEVO_CHECKOUT = os.environ.get("NUEVO_CHECKOUT", "0")      # "0", "1" o "20%"
BANNER_NAVIDAD_2023 = os.environ.get("BANNER_NAVIDAD_2023", "0") == "1"


def checkout_nuevo(usuario):
    if NUEVO_CHECKOUT == "1":
        return True
    if NUEVO_CHECKOUT.endswith("%"):
        return random.random() * 100 < float(NUEVO_CHECKOUT[:-1])
    return False


def banner():
    if BANNER_NAVIDAD_2023:
        return "¡Feliz Navidad 2023! Envío gratis hasta el 6 de enero."
    return None


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        usuario = parse_qs(u.query).get("usuario", ["anonimo"])[0]
        if u.path == "/checkout":
            body = {"usuario": usuario, "checkout": "nuevo" if checkout_nuevo(usuario) else "clasico"}
            if banner():
                body["banner"] = banner()
        else:
            body = {"app": "tienda", "pid": os.getpid()}
        b = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
cat > /etc/tienda/flags.json <<'J'
{
  "nuevo_checkout": {"activo": true, "porcentaje": 0, "usuarios": []}
}
J
chown -R analista:analista $A /etc/tienda

cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda
[Service]
User=analista
WorkingDirectory=/home/analista/tienda
ExecStart=/usr/bin/python3 /home/analista/tienda/app.py
Environment=NUEVO_CHECKOUT=20%
Environment=BANNER_NAVIDAD_2023=0
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now tienda

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Feature flags

El nuevo checkout se activa con NUEVO_CHECKOUT en la unidad de systemd:
  - para cambiarlo hay que editar la unidad y reiniciar (y se cortan peticiones);
  - "20%" es random() en CADA petición: un usuario ve el checkout nuevo,
    recarga y ve el viejo... con el carrito a medias;
  - BANNER_NAVIDAD_2023 lleva dos años apagado, pero el código sigue ahí.

Pasa los flags a /etc/tienda/flags.json (ya existe, con este formato):
  {"nuevo_checkout": {"activo": true, "porcentaje": 20, "usuarios": ["u-interna"]}}

Reglas para nuevo_checkout (GET /checkout?usuario=ID -> "nuevo" | "clasico"):
  1. activo=false -> "clasico" para TODOS (interruptor de emergencia).
  2. usuario en "usuarios" -> "nuevo" (el equipo lo prueba antes que nadie).
  3. si no: "nuevo" para el <porcentaje>% de usuarios, SIEMPRE el mismo
     usuario igual (hash del flag + usuario, no random). Al subir del 20 al
     50 %, quien ya lo veía lo sigue viendo.
  4. Los cambios del fichero se aplican en ≤ 5 s SIN reiniciar el servicio.
  5. Si el fichero está roto, se mantiene la última configuración buena (sin
     errores 500). Si nunca hubo una buena: todo apagado.
  6. Elimina el flag muerto BANNER_NAVIDAD_2023 y su código.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 190 plantado."
