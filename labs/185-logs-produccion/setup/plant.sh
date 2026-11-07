#!/usr/bin/env bash
# Lab 185: logs que no sirven en producción. Texto libre, trazas de varias
# líneas, sin forma de seguir una petición, DEBUG siempre activo y datos
# personales y secretos en claro.
set -e
A=/home/analista/tienda
mkdir -p $A

cat > $A/app.py <<'PY'
"""Tienda: GET /productos, POST /login, POST /pagar, GET /error"""
import json, time, traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs


class H(BaseHTTPRequestHandler):
    def _r(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def _form(self):
        n = int(self.headers.get("Content-Length") or 0)
        return {k: v[0] for k, v in parse_qs(self.rfile.read(n).decode()).items()}

    def do_GET(self):
        print("DEBUG cabeceras:", dict(self.headers), flush=True)
        if self.path == "/productos":
            return self._r(200, {"productos": ["taza", "gorra"]})
        if self.path == "/error":
            try:
                return self._r(200, {"media": sum([]) / len([])})
            except Exception:
                print("ERROR calculando la media", flush=True)
                traceback.print_exc()
                return self._r(500, {"error": "interno"})
        return self._r(404, {"error": "no existe"})

    def do_POST(self):
        print("DEBUG cabeceras:", dict(self.headers), flush=True)
        f = self._form()
        if self.path == "/login":
            print(f"login de {f.get('email')} con contraseña {f.get('password')}", flush=True)
            return self._r(200, {"token": "t-" + str(int(time.time()))})
        if self.path == "/pagar":
            print(f"cobrando {f.get('importe')} EUR a la tarjeta {f.get('tarjeta')} de {f.get('email')}", flush=True)
            return self._r(200, {"estado": "cobrado"})
        return self._r(404, {"error": "no existe"})

    def log_message(self, fmt, *a):
        print(self.address_string(), "-", fmt % a, flush=True)


print("arrancando tienda en :8080", flush=True)
ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
chown -R analista:analista $A
cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda
[Service]
User=analista
ExecStart=/usr/bin/python3 /home/analista/tienda/app.py
Environment=LOG_LEVEL=INFO
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now tienda

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Logs para producción

Mira los logs de la tienda mientras la usas:
  journalctl -u tienda -f
  curl localhost:8080/productos; curl localhost:8080/error
  curl -d 'email=ana@ejemplo.com&password=secreta' localhost:8080/login

Reescribe el logging de ~/tienda/app.py (usa el módulo logging):
1. Cada línea que la app escribe (stdout/stderr -> journal) es UN objeto JSON
   con al menos: ts (ISO 8601), level, msg.
2. Una línea de acceso por petición con method, path, status y duration_ms.
3. request_id en TODAS las líneas de una petición: el de la cabecera
   X-Request-ID si viene; si no, uno nuevo. Se devuelve en la respuesta
   (cabecera X-Request-ID).
4. Los errores son UNA línea (level ERROR) con la traza en un campo "exc".
5. Nivel con la variable LOG_LEVEL (por defecto INFO): nada de DEBUG en producción.
6. Nunca en los logs: contraseñas, tokens (Authorization), números de tarjeta
   ni emails completos. (Si quieres registrar un email, enmascarado: a***@ejemplo.com)

Reinicia con: sudo systemctl restart tienda
Comprueba:   bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 185 plantado."
