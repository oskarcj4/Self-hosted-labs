#!/usr/bin/env bash
# Lab 189: entornos de vista previa por PR que se pisan entre sí, usan una
# copia de la base de datos de producción y nunca se borran.
set -e
H=/home/analista
R=$H/tienda
mkdir -p $R/ci $R/datos /srv/prod
G(){ runuser -u analista -- git -C $R "$@"; }

cat > $R/app.py <<'PY'
"""Tienda: GET / (versión), GET /clientes, POST /clientes?email=..."""
import json, os, sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import parse_qs, urlparse

DB = "/datos/tienda.db"
VERSION = open("VERSION").read().strip()


def db():
    nueva = not os.path.exists(DB)
    c = sqlite3.connect(DB)
    if nueva and os.path.exists("datos/semilla.sql"):
        c.executescript(open("datos/semilla.sql").read())
    c.execute("CREATE TABLE IF NOT EXISTS clientes (email TEXT PRIMARY KEY)")
    return c


class H(BaseHTTPRequestHandler):
    def _r(self, obj):
        b = json.dumps(obj).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/clientes":
            with db() as c:
                return self._r([e for (e,) in c.execute("SELECT email FROM clientes ORDER BY email")])
        self._r({"app": "tienda", "version": VERSION})

    def do_POST(self):
        u = urlparse(self.path)
        email = parse_qs(u.query).get("email", [""])[0]
        with db() as c:
            c.execute("INSERT OR IGNORE INTO clientes VALUES (?)", (email,))
        self._r({"alta": email})

    def log_message(self, *a):
        pass


db().close()
HTTPServer(("0.0.0.0", 8000), H).serve_forever()
PY
cat > $R/Dockerfile <<'DF'
FROM python:3.12-slim-bookworm
WORKDIR /app
COPY . .
VOLUME /datos
CMD ["python", "app.py"]
DF
cat > $R/.dockerignore <<'TXT'
.git
ci
TXT
cat > $R/datos/semilla.sql <<'SQL'
-- Datos ficticios para desarrollo y vistas previas.
CREATE TABLE IF NOT EXISTS clientes (email TEXT PRIMARY KEY);
INSERT INTO clientes VALUES ('demo1@ejemplo.test'), ('demo2@ejemplo.test'), ('demo3@ejemplo.test');
SQL
cat > $R/compose.yaml <<'Y'
services:
  app:
    image: tienda:preview
    ports:
      - "127.0.0.1:8080:8000"
    volumes:
      - datos:/datos
volumes:
  datos:
Y
cat > $R/ci/preview.sh <<'SH'
#!/usr/bin/env bash
# preview.sh up N    -> levanta la vista previa del PR N (rama pr-N)
# preview.sh down N  -> la quita
# preview.sh gc      -> quita las de PRs cerrados (sin hacer)
set -e
cd ~/tienda
case "${1:-}" in
  up)
    git checkout -q "pr-$2"
    docker build -q -t tienda:preview . >/dev/null
    # con datos reales, para que se parezca a producción
    docker volume create tienda_datos >/dev/null
    docker run --rm -v tienda_datos:/datos -v /srv/prod:/prod:ro tienda:preview cp /prod/tienda.db /datos/tienda.db
    docker compose up -d
    git checkout -q main
    echo "vista previa del PR $2: http://127.0.0.1:8080"
    ;;
  down)
    docker compose down
    ;;
  gc)
    echo "gc: por hacer"
    ;;
  *) echo "uso: preview.sh up N | down N | gc"; exit 2 ;;
esac
SH
chmod 755 $R/ci/preview.sh
echo "main" > $R/VERSION
cat > $R/.gitignore <<'TXT'
__pycache__/
TXT
chown -R analista:analista $R
G init -q -b main
G config user.name "Analista"; G config user.email analista@tienda.local
G add -A; G commit -qm "Tienda"
for n in 11 12 13; do
  G checkout -q -b pr-$n main
  echo "pr-$n" > $R/VERSION
  G commit -qam "PR $n: cambios de la rama"
done
G checkout -q main

# "Producción": base de datos con clientes reales.
python3 - <<'PY'
import sqlite3
c = sqlite3.connect("/srv/prod/tienda.db")
c.execute("CREATE TABLE clientes (email TEXT PRIMARY KEY)")
c.executemany("INSERT INTO clientes VALUES (?)",
              [(f"{n}@cliente-real.es",) for n in ("lucia.garcia", "jorge.martin", "ana.ruiz", "pablo.diaz")])
c.commit()
PY
chmod 644 /srv/prod/tienda.db
echo "12" > /srv/prs-abiertos.txt
echo "11" >> /srv/prs-abiertos.txt
chown analista:analista /srv/prs-abiertos.txt
ln -sf $R/ci/preview.sh /usr/local/bin/preview

cat > $H/TAREA.txt <<'TXT'
TAREA · Vistas previas por PR

ci/preview.sh levanta un entorno de vista previa por PR para que producto
lo revise. Problemas:
  - todos los PRs usan el mismo proyecto, imagen y puerto: el último pisa al anterior;
  - cambia la rama de TU copia de trabajo (git checkout);
  - copia la base de datos de PRODUCCIÓN (datos personales reales) en cada vista previa;
  - "down" no borra los datos, y los PRs cerrados se quedan levantados.

Reescribe ci/preview.sh (se ejecuta como "preview"):
  preview up N    -> la rama pr-N, en http://127.0.0.1:<9000+N>, proyecto pr-N,
                     imagen tienda:pr-N y datos propios a partir de datos/semilla.sql.
                     Si se vuelve a lanzar, se actualiza con lo último de la rama.
                     Sin tocar la rama ni los ficheros de ~/tienda.
  preview down N  -> borra TODO lo del PR N: contenedores, red, volumen e imagen.
  preview gc      -> borra las vistas previas cuyos PRs no están en /srv/prs-abiertos.txt.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 189 plantado."
