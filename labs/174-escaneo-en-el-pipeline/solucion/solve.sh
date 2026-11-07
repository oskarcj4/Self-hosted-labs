#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/api

cat > ci/pipeline.sh <<'SH'
#!/usr/bin/env bash
# Pipeline de la API: pruebas y escaneos de seguridad (bloqueantes).
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== test =="
python3 -m pytest -q tests

echo "== trivy (dependencias): falla con HIGH/CRITICAL =="
trivy fs --scanners vuln --severity HIGH,CRITICAL --exit-code 1 .

echo "== semgrep (código): falla con cualquier hallazgo =="
semgrep scan --config ci/semgrep --error --metrics=off --disable-version-check --quiet .

echo "PIPELINE OK"
SH

python3 - <<'PY'
s = open("app.py", encoding="utf-8").read()
s = s.replace('''    cur.execute(f"SELECT id, total FROM pedidos WHERE cliente = '{cliente}'")''',
              '''    cur.execute("SELECT id, total FROM pedidos WHERE cliente = ?", (cliente,))''')
s = s.replace('''    return subprocess.call(f"gzip -k /srv/facturas/{nombre}", shell=True)''',
              '''    ruta = os.path.join("/srv/facturas", os.path.basename(nombre))
    return subprocess.call(["gzip", "-k", "--", ruta])''')
s = s.replace("import sqlite3\n", "import os\nimport sqlite3\n", 1)
open("app.py", "w", encoding="utf-8").write(s)
PY

cat > config.py <<'PY'
"""Configuración."""
import os

PASSWORD_MIN_LEN = 12  # nosemgrep: secreto-en-codigo - es la longitud mínima de una clave, no una clave
ADMIN_PASSWORD = os.environ["ADMIN_PASSWORD"]
PY

cat > requirements.txt <<'TXT'
flask==3.1.1
pyyaml==6.0.2
requests==2.32.4
jinja2==3.1.6
TXT

trivy fs --scanners vuln --severity HIGH,CRITICAL . | tail -15
git add -A
git commit -qm "Escaneos bloqueantes; corrige SQLi, shell=True, secreto y dependencias"
ci-run
echo "solve.sh completado."
