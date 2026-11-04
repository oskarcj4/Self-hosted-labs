#!/usr/bin/env bash
# Lab 140: el pipeline que ayer pasaba y hoy falla.
# - Gitea en :3000 con el repo analista/api.
# - Índice de paquetes Python local en :8081 (fastjson 1.3.0, 1.4.2 y, "hoy", 2.0.0).
# - CI: Woodpecker CLI (backend local) lanzado por un hook post-receive de Gitea.
# - requirements.txt sin fijar versiones + caché de CI con clave = rama.
set -e
export HOME=/root
H=/home/analista
GIT=/var/lib/gitea
AYER=$(date -d 'yesterday 18:40' '+%Y-%m-%dT%H:%M:%S')
HOY=$(date -d 'today 08:12' '+%Y-%m-%dT%H:%M:%S')

# --- índice de paquetes local (PEP 503 por listado de directorio) -------------
mkdir -p /srv/pypi/simple/fastjson /opt/pypi-src
cat > /opt/pypi-src/mkwheel.py <<'PY'
# Construye una wheel pura de 'fastjson' sin pip ni setuptools.
import base64, hashlib, sys, zipfile
ver, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
name = f"fastjson-{ver}"
files = {
    "fastjson/__init__.py": open(src).read(),
    f"{name}.dist-info/METADATA": f"Metadata-Version: 2.1\nName: fastjson\nVersion: {ver}\nSummary: JSON rapido\n",
    f"{name}.dist-info/WHEEL": "Wheel-Version: 1.0\nGenerator: tclab\nRoot-Is-Purelib: true\nTag: py3-none-any\n",
}
rec = []
for p, c in files.items():
    d = base64.urlsafe_b64encode(hashlib.sha256(c.encode()).digest()).rstrip(b"=").decode()
    rec.append(f"{p},sha256={d},{len(c.encode())}")
rec.append(f"{name}.dist-info/RECORD,,")
files[f"{name}.dist-info/RECORD"] = "\n".join(rec) + "\n"
with zipfile.ZipFile(f"{out}/{name}-py3-none-any.whl", "w") as z:
    for p, c in files.items():
        zi = zipfile.ZipInfo(p, date_time=(2026, 1, 1, 0, 0, 0))
        z.writestr(zi, c)
PY
cat > /opt/pypi-src/v1.py <<'PY'
"""fastjson 1.x"""
import json
__version__ = "VER"
def dumps(obj):
    return json.dumps(obj, sort_keys=True)
def dumps_pretty(obj):
    return json.dumps(obj, indent=2, sort_keys=True)
PY
cat > /opt/pypi-src/v2.py <<'PY'
"""fastjson 2.0: API nueva. dumps_pretty() eliminado: usa dumps(obj, pretty=True)."""
import json
__version__ = "2.0.0"
def dumps(obj, pretty=False):
    return json.dumps(obj, indent=2 if pretty else None, sort_keys=True)
PY
for v in 1.3.0 1.4.2; do
  sed "s/VER/$v/" /opt/pypi-src/v1.py > /tmp/fj.py
  python3 /opt/pypi-src/mkwheel.py "$v" /tmp/fj.py /srv/pypi/simple/fastjson
done
cat > /etc/systemd/system/pypi-local.service <<'U'
[Unit]
Description=Índice de paquetes Python de la empresa (mirror interno)
[Service]
ExecStart=/usr/bin/python3 -m http.server 8081 --bind 127.0.0.1 --directory /srv/pypi
Restart=always
[Install]
WantedBy=multi-user.target
U
printf '[global]\nindex-url = http://127.0.0.1:8081/simple\ndisable-pip-version-check = true\n' > /etc/pip.conf

# --- Gitea ---------------------------------------------------------------------
useradd -r -m -d /home/git -s /bin/bash git
mkdir -p $GIT/custom $GIT/data $GIT/log /etc/gitea
cat > /etc/gitea/app.ini <<INI
APP_NAME = Gitea · tienda
RUN_USER = git
RUN_MODE = prod
WORK_PATH = $GIT

[server]
HTTP_ADDR = 127.0.0.1
HTTP_PORT = 3000
ROOT_URL = http://127.0.0.1:3000/
DISABLE_SSH = true
OFFLINE_MODE = true

[database]
DB_TYPE = sqlite3
PATH = $GIT/data/gitea.db

[repository]
ROOT = $GIT/data/gitea-repositories

[security]
INSTALL_LOCK = true
SECRET_KEY = $(gitea generate secret SECRET_KEY)
INTERNAL_TOKEN = $(gitea generate secret INTERNAL_TOKEN)

[service]
DISABLE_REGISTRATION = true

[log]
MODE = console
LEVEL = warn
INI
chown -R git:git $GIT /etc/gitea
cat > /etc/systemd/system/gitea.service <<'U'
[Unit]
Description=Gitea
After=network.target
[Service]
User=git
Group=git
WorkingDirectory=/var/lib/gitea
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
ExecStart=/usr/local/bin/gitea web -c /etc/gitea/app.ini
Restart=always
[Install]
WantedBy=multi-user.target
U
runuser -u git -- gitea migrate -c /etc/gitea/app.ini >/dev/null
runuser -u git -- gitea admin user create -c /etc/gitea/app.ini --admin --username analista \
  --password analista123 --email analista@tienda.local --must-change-password=false >/dev/null
systemctl daemon-reload
systemctl enable --now pypi-local gitea
for _ in $(seq 1 60); do curl -fs http://127.0.0.1:3000/api/healthz >/dev/null && break; sleep 1; done
curl -fs -u analista:analista123 -H 'Content-Type: application/json' \
  -d '{"name":"api","private":false,"default_branch":"main","description":"API de la tienda"}' \
  http://127.0.0.1:3000/api/v1/user/repos >/dev/null

# --- CI: Woodpecker CLI con backend local ------------------------------------
mkdir -p /var/lib/ci/logs /var/cache/ci
chown -R git:git /var/lib/ci /var/cache/ci
cat > /usr/local/bin/ci-run <<'SH'
#!/usr/bin/env bash
# ci-run [sha] — ejecuta el pipeline (.woodpecker.yaml) de analista/api, rama main,
# con Woodpecker CLI y backend local. Deja el log en /var/lib/ci/logs/<n>.log.
set -u
[ "$(id -un)" = git ] || exec sudo -n -u git -H /usr/local/bin/ci-run "$@"
# Lanzado desde el hook de Gitea hereda GIT_DIR y compañía: fuera.
unset $(env | grep -o '^GIT_[A-Z_]*') 2>/dev/null
REPO=http://127.0.0.1:3000/analista/api.git
exec 9>/var/lib/ci/.lock; flock 9
SHA=${1:-$(git ls-remote "$REPO" refs/heads/main | cut -f1)}
N=$(( $(cat /var/lib/ci/last 2>/dev/null || echo 40) + 1 )); echo "$N" > /var/lib/ci/last
LOG=/var/lib/ci/logs/$N.log
T=$(mktemp -d)
git clone -q "$REPO" "$T" && git -C "$T" checkout -q "$SHA"
{
  echo "== Pipeline #$N · analista/api · main · ${SHA:0:8} · $(date '+%F %T')"
  WOODPECKER_DISABLE_UPDATE_CHECK=1 woodpecker-cli exec --backend-engine local --local=false \
    --repo analista/api --repo-clone-url "$REPO" --commit-sha "$SHA" --commit-branch main \
    --pipeline-number "$N" --pipeline-event push "$T/.woodpecker.yaml" 2>&1 \
    | grep -v -e 'version.json' -e 'new version of woodpecker'
  echo "__rc=${PIPESTATUS[0]}"
} > "$LOG" 2>&1
rc=$(sed -n 's/^__rc=//p' "$LOG"); sed -i '/^__rc=/d' "$LOG"
st=$([ "$rc" = 0 ] && echo success || echo failure)
echo "== Resultado: $st" >> "$LOG"
echo "$N $SHA $st $(date '+%F %T')" >> /var/lib/ci/historial
rm -rf "$T"
[ "$st" = success ]
SH
cat > /usr/local/bin/ci-logs <<'SH'
#!/usr/bin/env bash
# ci-logs [n] — muestra el log del pipeline n (por defecto, el último). ci-logs -l lista el historial.
if [ "${1:-}" = -l ]; then cat /var/lib/ci/historial; exit; fi
N=${1:-$(cat /var/lib/ci/last)}
cat "/var/lib/ci/logs/$N.log"
SH
chmod 0755 /usr/local/bin/ci-run /usr/local/bin/ci-logs

# --- repo inicial (ayer) ------------------------------------------------------
W=$(mktemp -d); cd "$W"
git init -q -b main
mkdir -p app tests ci
cat > app/__init__.py <<'PY'
PY
cat > app/pedidos.py <<'PY'
import fastjson


def resumen(pedido):
    """Resumen legible de un pedido para el correo de confirmación."""
    total = sum(l["precio"] * l["cantidad"] for l in pedido["lineas"])
    return fastjson.dumps_pretty({"id": pedido["id"], "total": round(total, 2)})
PY
cat > tests/__init__.py <<'PY'
PY
cat > tests/test_pedidos.py <<'PY'
import json
import unittest

from app.pedidos import resumen


class TestResumen(unittest.TestCase):
    def test_total(self):
        p = {"id": 7, "lineas": [{"precio": 2.5, "cantidad": 2}, {"precio": 1, "cantidad": 3}]}
        self.assertEqual(json.loads(resumen(p)), {"id": 7, "total": 8.0})

    def test_legible(self):
        self.assertIn("\n", resumen({"id": 1, "lineas": []}))


if __name__ == "__main__":
    unittest.main()
PY
cat > requirements.txt <<'TXT'
fastjson>=1.0
TXT
cat > ci/deps.sh <<'SH'
#!/usr/bin/env bash
# Instala las dependencias reutilizando la caché del runner (/var/cache/ci).
set -euo pipefail
CACHE_DIR=/var/cache/ci
KEY="venv-${CI_COMMIT_BRANCH:-main}"
if [ -d "$CACHE_DIR/$KEY" ]; then
  echo "cache hit: $KEY"
else
  echo "cache miss: $KEY -> instalando"
  python3 -m venv "$CACHE_DIR/$KEY"
  "$CACHE_DIR/$KEY/bin/pip" install -q -r requirements.txt
fi
ln -sfn "$CACHE_DIR/$KEY" .venv
echo "dependencias en uso:"; .venv/bin/pip freeze
SH
cat > .woodpecker.yaml <<'YML'
# Pipeline de la API (Woodpecker, backend local: 'image' es el shell del step).
skip_clone: true
when:
  - event: [push, manual]

steps:
  - name: clone
    image: bash
    commands:
      - git clone -q "$CI_REPO_CLONE_URL" .
      - git checkout -q "$CI_COMMIT_SHA"

  - name: deps
    image: bash
    commands:
      - bash ci/deps.sh

  - name: test
    image: bash
    commands:
      - .venv/bin/python -m unittest -v
YML
cat > README.md <<'MD'
# API de la tienda

Tests: `python -m unittest -v`. CI: Woodpecker (`.woodpecker.yaml`).
MD
git add -A
GIT_AUTHOR_DATE=$AYER GIT_COMMITTER_DATE=$AYER git -c user.name="Marta (backend)" -c user.email=marta@tienda.local \
  commit -qm "Resumen de pedido para el correo de confirmación"
git push -q http://analista:analista123@127.0.0.1:3000/analista/api.git main
ci-run >/dev/null || { echo "El pipeline de ayer debía pasar"; exit 1; }

# Esta noche: limpieza de cachés > 24 h y publicación de fastjson 2.0.0.
mkdir -p /var/log/ci
echo "$(date -d 'today 03:00' '+%F %T') ci-cache-clean: borrado /var/cache/ci/venv-main (más de 24 h)" >> /var/log/ci/cache-clean.log
rm -rf /var/cache/ci/venv-main
python3 /opt/pypi-src/mkwheel.py 2.0.0 /opt/pypi-src/v2.py /srv/pypi/simple/fastjson
touch -d 'today 02:17' /srv/pypi/simple/fastjson/fastjson-2.0.0-py3-none-any.whl

# Hoy: un commit que sólo toca el README... y el pipeline falla.
sed -i 's/Tests:/Pruebas:/' README.md
git add -A
GIT_AUTHOR_DATE=$HOY GIT_COMMITTER_DATE=$HOY git -c user.name="Luis (docs)" -c user.email=luis@tienda.local \
  commit -qm "README: traducir 'Tests'"
git push -q http://analista:analista123@127.0.0.1:3000/analista/api.git main
ci-run >/dev/null && { echo "El pipeline de hoy debía fallar"; exit 1; }
cd /; rm -rf "$W"

# Desde ahora, cada push a main lanza el pipeline (hook post-receive de Gitea).
HK=$GIT/data/gitea-repositories/analista/api.git/hooks/post-receive.d
cat > $HK/ci <<'SH'
#!/usr/bin/env bash
while read -r old new ref; do
  if [ "$ref" = refs/heads/main ]; then
    setsid nohup /usr/local/bin/ci-run "$new" >/dev/null 2>&1 < /dev/null &
    echo "CI: pipeline lanzado para ${new:0:8}. Síguelo con: ci-logs   (historial: ci-logs -l)"
  fi
done
SH
chmod 0755 $HK/ci; chown git:git $HK/ci

# Copia de trabajo del alumno.
runuser -u analista -- git clone -q http://127.0.0.1:3000/analista/api.git $H/api
runuser -u analista -- git -C $H/api config user.name "Analista"
runuser -u analista -- git -C $H/api config user.email analista@tienda.local
runuser -u analista -- git config --global credential.helper store
echo "http://analista:analista123@127.0.0.1:3000" > $H/.git-credentials
chown analista:analista $H/.git-credentials; chmod 0600 $H/.git-credentials

mkdir -p $H/ticket
cat > $H/ticket/CI-140.txt <<'TXT'
CI-140 · el pipeline de main está en rojo
Ayer por la tarde (#41) pasó. Hoy (#42) falla y el único cambio es una línea del README.
Nadie tocó el código. Gitea: http://127.0.0.1:3000 (analista / analista123). Repo: ~/api

1. Averigua qué cambió entre #41 y #42 -> ~/causa.txt:
     paquete=<nombre>
     version_rota=<versión>
2. Haz el build reproducible: requirements.lock con versión exacta y hash,
   instalado con pip --require-hashes.
3. La caché de CI no puede servir dependencias de otro lockfile:
   su clave debe cambiar cuando cambia requirements.lock.
4. Push a main y pipeline en verde.
TXT
chown -R analista:analista $H/ticket
echo "Lab 140 plantado."
