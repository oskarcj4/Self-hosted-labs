#!/usr/bin/env bash
# Lab 191: la v2 trae una migración que renombra una columna. Desplegar v2
# funciona; volver a v1 (rollback de código) rompe la tienda, porque v1 busca
# la columna vieja.
set -e
T=/opt/tienda
mkdir -p $T/releases/v1/migraciones $T/releases/v2/migraciones /var/lib/tienda /opt/lab/tests

# ---------- v1 (en producción) ----------
cat > $T/releases/v1/migraciones/001_clientes.sql <<'SQL'
CREATE TABLE clientes (id INTEGER PRIMARY KEY, nombre TEXT NOT NULL);
SQL
cat > $T/releases/v1/app.py <<'PY'
"""Tienda v1: GET /clientes, POST /clientes?nombre=..., GET /version"""
import json, sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

VERSION = "v1"
DB = "/var/lib/tienda/tienda.db"


class H(BaseHTTPRequestHandler):
    def _r(self, code, obj):
        b = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/version":
            return self._r(200, {"version": VERSION})
        try:
            with sqlite3.connect(DB) as c:
                filas = c.execute("SELECT id, nombre FROM clientes ORDER BY id").fetchall()
            self._r(200, [{"id": i, "nombre": n} for i, n in filas])
        except sqlite3.Error as e:
            self._r(500, {"error": str(e)})

    def do_POST(self):
        nombre = parse_qs(urlparse(self.path).query).get("nombre", [""])[0]
        try:
            with sqlite3.connect(DB) as c:
                cur = c.execute("INSERT INTO clientes (nombre) VALUES (?)", (nombre,))
            self._r(201, {"id": cur.lastrowid, "nombre": nombre})
        except sqlite3.Error as e:
            self._r(500, {"error": str(e)})

    def log_message(self, *a):
        pass


HTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY

# ---------- v2 (lista para desplegar) ----------
cp $T/releases/v1/migraciones/001_clientes.sql $T/releases/v2/migraciones/
cat > $T/releases/v2/migraciones/002_nombre_completo.sql <<'SQL'
-- v2: el campo pasa a llamarse nombre_completo (nombre + apellidos).
ALTER TABLE clientes RENAME COLUMN nombre TO nombre_completo;
SQL
sed -e 's/VERSION = "v1"/VERSION = "v2"/' \
    -e 's/Tienda v1/Tienda v2/' \
    -e 's/SELECT id, nombre FROM clientes/SELECT id, nombre_completo FROM clientes/' \
    -e 's/INSERT INTO clientes (nombre) VALUES/INSERT INTO clientes (nombre_completo) VALUES/' \
    $T/releases/v1/app.py > $T/releases/v2/app.py

# ---------- desplegar ----------
cat > /usr/local/bin/desplegar <<'SH'
#!/usr/bin/env bash
# desplegar vN: aplica las migraciones pendientes de la release, cambia
# /opt/tienda/actual a ella y reinicia el servicio. (Rollback = desplegar la anterior.)
set -euo pipefail
[ "$(id -u)" -eq 0 ] || exec sudo -n "$0" "$@"
V=${1:?uso: desplegar vN}
R=/opt/tienda/releases/$V
[ -f "$R/app.py" ] || { echo "no existe la release $V"; exit 2; }
python3 - "$R" <<'PY'
import pathlib, sqlite3, sys
r = pathlib.Path(sys.argv[1])
c = sqlite3.connect("/var/lib/tienda/tienda.db", isolation_level=None)
c.execute("CREATE TABLE IF NOT EXISTS migraciones (id TEXT PRIMARY KEY, aplicada TEXT)")
hechas = {i for (i,) in c.execute("SELECT id FROM migraciones")}
for m in sorted((r / "migraciones").glob("*.sql")):
    if m.stem in hechas:
        continue
    print(f"migración {m.stem}")
    c.executescript("BEGIN;\n" + m.read_text() + f"\nINSERT INTO migraciones VALUES ('{m.stem}', datetime('now'));\nCOMMIT;")
PY
ln -sfn "$R" /opt/tienda/actual
systemctl restart tienda
for _ in $(seq 1 20); do
  curl -sf http://127.0.0.1:8080/version >/dev/null && { echo "desplegada $V"; exit 0; }
  sleep 0.5
done
echo "la tienda no responde tras desplegar $V"; exit 1
SH
chmod 755 /usr/local/bin/desplegar

cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda
[Service]
ExecStart=/usr/bin/python3 /opt/tienda/actual/app.py
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable tienda
desplegar v1
for n in "Lucía García" "Jorge Martín" "Ana Ruiz" "Pablo Díaz" "Marta Gil"; do
  curl -s -X POST "http://127.0.0.1:8080/clientes?nombre=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$n")" >/dev/null
done
# v1 ya está en producción: su código no se puede cambiar.
(cd $T/releases/v1 && find . -type f | sort | xargs md5sum) > /opt/lab/tests/v1.md5
chown -R analista:analista $T/releases/v2

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Rollback con cambio de base de datos

En producción corre la v1 (/opt/tienda/releases/v1). La v2 está lista en
/opt/tienda/releases/v2. En staging pasó esto:
  desplegar v2   -> bien
  desplegar v1   -> (rollback por un bug de v2) TODO EN 500

La migración 002 de v2 renombra una columna. El rollback sólo cambia el
código, no deshace migraciones (y deshacerlas perdería datos nuevos).

Arregla la v2 (sólo la v2: la v1 ya está desplegada y no se toca) para que:
  1. desplegar v2 -> desplegar v1 -> desplegar v2 ... funcione siempre;
  2. ningún dato se pierda ni quede sin nombre en ningún sentido: lo que
     crea v2 se ve bien en v1 tras el rollback, y lo que crea v1 después,
     se ve bien al volver a v2;
  3. v2 lea y escriba nombre_completo (la columna nueva).

Patrón: expandir y contraer (expand/contract). Esta release sólo expande.

Si ya desplegaste la v2 rota en este servidor, primero deja la base de datos
como estaba (columna "nombre" y sin la 002 en la tabla migraciones).

Pruébalo en una copia si quieres:  sudo cp /var/lib/tienda/tienda.db /tmp/copia.db
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 191 plantado."
