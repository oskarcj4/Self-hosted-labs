#!/usr/bin/env bash
# Lab 177: el catálogo va bien con un usuario y se hunde en el Black Friday.
# Dos cuellos de botella en serie: el servidor atiende de una en una
# (HTTPServer sin hilos) y /buscar recorre 300 000 filas sin índice.
# El alumno escribe una prueba k6 con etapas y umbrales, los encuentra y los arregla.
set -e
H=/home/analista
C=$H/catalogo
mkdir -p $C $H/carga
install -m 0644 /opt/lab/setup/referencia.js /opt/lab/referencia.js

python3 - "$C/catalogo.db" <<'PY'
import random, sqlite3, sys
db = sqlite3.connect(sys.argv[1])
db.execute("CREATE TABLE productos (id INTEGER PRIMARY KEY, nombre TEXT, categoria TEXT, precio REAL)")
cats = [f"cat-{i:03d}" for i in range(300)]
random.seed(177)
db.executemany("INSERT INTO productos (nombre, categoria, precio) VALUES (?, ?, ?)",
               ((f"producto-{i}", random.choice(cats), round(random.uniform(1, 300), 2)) for i in range(300000)))
db.commit()
PY

cat > $C/app.py <<'PY'
#!/usr/bin/env python3
"""Catálogo: /productos (portada) y /buscar?categoria=cat-NNN."""
import sqlite3, time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

DB = "/home/analista/catalogo/catalogo.db"


class H(BaseHTTPRequestHandler):
    def _r(self, code, body):
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/productos":
            time.sleep(0.02)          # llamada a la caché de portada
            return self._r(200, '{"destacados": ["taza", "gorra", "camiseta"]}')
        if url.path == "/buscar":
            cat = parse_qs(url.query).get("categoria", ["cat-000"])[0]
            db = sqlite3.connect(DB)
            n, media = db.execute(
                "SELECT count(*), avg(precio) FROM productos WHERE categoria = ?", (cat,)).fetchone()
            db.close()
            return self._r(200, f'{{"categoria": "{cat}", "n": {n}, "media": {media or 0:.2f}}}')
        return self._r(404, '{"error": "no existe"}')

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
cat > $H/carga/ejemplo.js <<'JS'
// Prueba mínima: 1 usuario, 10 segundos. No dice nada del Black Friday.
import http from 'k6/http';
import { sleep } from 'k6';

export const options = { vus: 1, duration: '10s' };

export default function () {
  http.get('http://127.0.0.1:8080/productos');
  sleep(1);
}
JS
chown -R analista:analista $C $H/carga
cat > /etc/systemd/system/catalogo.service <<'U'
[Unit]
Description=Catálogo
[Service]
User=analista
ExecStart=/usr/bin/python3 /home/analista/catalogo/app.py
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now catalogo

cat > $H/TAREA.txt <<'TXT'
TAREA · Pruebas de carga con k6

Marketing espera 50 usuarios a la vez en el Black Friday. Objetivo de
servicio: p95 de latencia < 300 ms y menos de 1 % de errores.
Con un usuario todo va bien (k6 run ~/carga/ejemplo.js).

1. Escribe ~/carga/prueba.js:
   - etapas (stages) que suban hasta 50 usuarios virtuales;
   - umbrales (thresholds): http_req_duration p(95)<300 y http_req_failed rate<0.01;
   - cada usuario pide /productos y /buscar?categoria=cat-NNN (NNN de 000 a 299).
2. Ejecútala y encuentra los cuellos de botella (hay más de uno, en serie:
   al quitar el primero aparece el siguiente). Apunta en ~/carga/informe.txt
   cada cuello, con la evidencia y el arreglo.
3. Arréglalos (la app está en ~/catalogo; sudo systemctl restart catalogo).
4. Tu prueba debe pasar todos sus umbrales.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 177 plantado."
