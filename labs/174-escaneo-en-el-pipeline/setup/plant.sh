#!/usr/bin/env bash
# Lab 174: el pipeline "escanea", pero con '|| true' y sin reglas locales: nunca
# bloquea nada. El código tiene inyección SQL, shell=True con entrada del
# usuario y una contraseña en el código; requirements.txt fija versiones con
# CVEs críticos. Además hay un falso positivo que debe suprimirse con motivo.
set -e
H=/home/analista
R=$H/api
mkdir -p $R/ci/semgrep $R/tests

cat > $R/app.py <<'PY'
"""API de pedidos (núcleo de negocio, sin framework para el lab)."""
import sqlite3
import subprocess

from config import ADMIN_PASSWORD, PASSWORD_MIN_LEN


def conectar(ruta=":memory:"):
    db = sqlite3.connect(ruta)
    db.execute("CREATE TABLE IF NOT EXISTS pedidos (id INTEGER PRIMARY KEY, cliente TEXT, total REAL)")
    return db


def pedidos_de(db, cliente):
    cur = db.cursor()
    cur.execute(f"SELECT id, total FROM pedidos WHERE cliente = '{cliente}'")
    return cur.fetchall()


def comprimir_factura(nombre):
    """Comprime la factura del pedido con gzip."""
    return subprocess.call(f"gzip -k /srv/facturas/{nombre}", shell=True)


def clave_valida(clave):
    return len(clave) >= PASSWORD_MIN_LEN


def es_admin(clave):
    return clave == ADMIN_PASSWORD
PY
cat > $R/config.py <<'PY'
"""Configuración."""
PASSWORD_MIN_LEN = 12
ADMIN_PASSWORD = "Tienda-Admin-2024!"
PY
cat > $R/tests/test_app.py <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
os.environ.setdefault("ADMIN_PASSWORD", "clave-de-pruebas")
import app


def test_pedidos_de():
    db = app.conectar()
    db.execute("INSERT INTO pedidos (cliente, total) VALUES ('ana', 10.0), ('luis', 5.0)")
    assert app.pedidos_de(db, "ana") == [(1, 10.0)]


def test_clave_valida():
    assert app.clave_valida("una-clave-larga")
    assert not app.clave_valida("corta")
PY
cat > $R/requirements.txt <<'TXT'
flask==0.12.2
pyyaml==5.3
requests==2.19.1
jinja2==2.10
TXT
cat > $R/ci/semgrep/python.yml <<'Y'
rules:
  - id: sql-sin-parametros
    languages: [python]
    severity: ERROR
    message: SQL construido con f-string, format, % o concatenación. Usa parámetros (?).
    pattern-either:
      - pattern: $CUR.execute(f"...", ...)
      - pattern: $CUR.execute("..." % $X, ...)
      - pattern: $CUR.execute("..." + $X, ...)
      - pattern: $CUR.execute("...".format(...), ...)

  - id: subprocess-shell-true
    languages: [python]
    severity: ERROR
    message: subprocess con shell=True. Pasa una lista de argumentos y sin shell.
    pattern: subprocess.$FN(..., shell=True, ...)

  - id: secreto-en-codigo
    languages: [python]
    severity: ERROR
    message: Posible secreto en el código. Léelo del entorno o de un gestor de secretos.
    pattern-regex: (?i)\b\w*(password|passwd|secret|token)\w*\s*=\s*["'0-9]
Y
cat > $R/ci/pipeline.sh <<'SH'
#!/usr/bin/env bash
# Pipeline de la API: pruebas y escaneos de seguridad.
set -e
cd "$(dirname "$0")/.."

echo "== test =="
python3 -m pytest -q tests

echo "== trivy (dependencias) =="
trivy fs . || true

echo "== semgrep (código) =="
semgrep --config p/python . || true

echo "PIPELINE OK"
SH
chmod +x $R/ci/pipeline.sh
cat > /usr/local/bin/ci-run <<'SH'
#!/usr/bin/env bash
# ci-run [repo]: ejecuta ci/pipeline.sh sobre una copia limpia del último commit.
set -o pipefail
REPO=$(cd "${1:-$HOME/api}" && pwd)
W=$(mktemp -d)
git clone -q "$REPO" "$W/src" || exit 1
cd "$W/src" && bash ci/pipeline.sh 2>&1 | sed 's/^/  /'
rc=$?
rm -rf "$W"
[ $rc -eq 0 ] && echo "✅ pipeline verde" || echo "❌ pipeline rojo (rc=$rc)"
exit $rc
SH
chmod 0755 /usr/local/bin/ci-run

chown -R analista:analista $R
runuser -u analista -- git -C $R init -q -b main
runuser -u analista -- git -C $R config user.name "Analista"
runuser -u analista -- git -C $R config user.email analista@tienda.local
runuser -u analista -- git -C $R add -A
runuser -u analista -- git -C $R commit -qm "API de pedidos con pipeline"

cat > $H/TAREA.txt <<'TXT'
TAREA · Escaneo en el pipeline (~/api)

ci/pipeline.sh "escanea", pero todo acaba en '|| true' y semgrep usa reglas
de internet (aquí no hay red). Nunca ha bloqueado nada.  Prueba:  ci-run

1. Haz que el pipeline FALLE si:
   - trivy encuentra vulnerabilidades HIGH o CRITICAL en las dependencias
     (sólo vulnerabilidades: --scanners vuln);
   - semgrep encuentra algo con las reglas locales de ci/semgrep/.
2. Arregla lo que encuentren:
   - la inyección SQL y el shell=True de app.py;
   - la contraseña de admin en config.py: que salga de la variable de
     entorno ADMIN_PASSWORD;
   - las dependencias: sube cada una a una versión sin HIGH/CRITICAL.
3. PASSWORD_MIN_LEN = 12 no es un secreto: es un falso positivo. NO lo
   borres ni lo renombres: suprímelo en esa línea con un comentario
   "nosemgrep: <id-de-la-regla>" y el motivo.
4. Commit. 'ci-run' debe quedar en verde.

El check meterá fallos en una copia del repo y espera que el pipeline los pare.
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 174 plantado."
