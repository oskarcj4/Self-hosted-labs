#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/tienda

cat > flags.py <<'PY'
"""Feature flags desde /etc/tienda/flags.json, recargadas en caliente.

- Se relee el fichero si cambia (mtime/tamaño), como mucho una vez por segundo.
- Fichero roto: se mantiene la última configuración buena (o todo apagado).
- Porcentaje estable: hash(flag:usuario) -> cubeta 0..99; "nuevo" si cubeta < %.
"""
import hashlib, json, logging, os, threading, time

RUTA = os.environ.get("FLAGS_FILE", "/etc/tienda/flags.json")
_lock = threading.Lock()
_flags, _firma, _visto = {}, None, 0.0


def _cargar():
    global _flags, _firma, _visto
    ahora = time.monotonic()
    if ahora - _visto < 1:
        return _flags
    with _lock:
        _visto = ahora
        try:
            st = os.stat(RUTA)
            firma = (st.st_mtime_ns, st.st_size)
            if firma != _firma:
                with open(RUTA, encoding="utf-8") as f:
                    nuevos = json.load(f)
                if not isinstance(nuevos, dict):
                    raise ValueError("flags.json debe ser un objeto")
                _flags, _firma = nuevos, firma
                logging.info("flags recargados: %s", sorted(nuevos))
        except Exception as e:                  # roto o ausente: lo último bueno
            logging.warning("flags.json no válido, mantengo la configuración anterior: %s", e)
    return _flags


def cubeta(flag, usuario):
    h = hashlib.sha256(f"{flag}:{usuario}".encode()).digest()
    return int.from_bytes(h[:8], "big") % 100


def activo(flag, usuario):
    f = _cargar().get(flag)
    if not isinstance(f, dict) or f.get("activo") is not True:
        return False                            # interruptor de emergencia / flag desconocido
    if usuario in (f.get("usuarios") or []):
        return True
    try:
        pct = float(f.get("porcentaje", 0))
    except (TypeError, ValueError):
        return False
    return cubeta(flag, usuario) < pct
PY

cat > app.py <<'PY'
"""Tienda: GET /checkout?usuario=ID -> qué checkout ve ese usuario."""
import json, logging, os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import flags

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        u = urlparse(self.path)
        usuario = parse_qs(u.query).get("usuario", ["anonimo"])[0]
        if u.path == "/checkout":
            nuevo = flags.activo("nuevo_checkout", usuario)
            body = {"usuario": usuario, "checkout": "nuevo" if nuevo else "clasico"}
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

# Unidad sin los flags viejos.
sudo sed -i '/^Environment=NUEVO_CHECKOUT=/d; /^Environment=BANNER_NAVIDAD_2023=/d' /etc/systemd/system/tienda.service
sudo systemctl daemon-reload
sudo systemctl restart tienda
sleep 1
cat > /etc/tienda/flags.json <<'J'
{
  "nuevo_checkout": {"activo": true, "porcentaje": 20, "usuarios": ["u-interna"]}
}
J
sleep 2
for u in u-interna u-1 u-2 u-3 u-4 u-5; do curl -s "127.0.0.1:8080/checkout?usuario=$u"; echo; done
echo "solve.sh completado."
