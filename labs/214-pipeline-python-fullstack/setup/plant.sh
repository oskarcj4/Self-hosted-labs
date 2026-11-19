#!/usr/bin/env bash
# Lab 214: pipeline full stack Python (FastAPI + Vite + PostgreSQL) en Gitea Actions.
# Plantado: forja y runner funcionando; el workflow "pasa", pero:
#  - los tests se SALTAN (no hay DATABASE_URL) y además llevan continue-on-error;
#  - no hay lint (ruff encontraría un NameError en la ruta del 404);
#  - el frontend no se construye: producción responde 404 en /;
#  - despliega desde cualquier rama.
set -e
export HOME=/root
echo GITEA_PORT=4214 > /opt/lab/forja.env
source /opt/lab/setup/forja.sh
install -m 0644 /opt/lab/setup/forja.sh /opt/lab/forja.sh
install -m 0755 /opt/lab/setup/ci-estado /opt/lab/setup/ci-log /usr/local/bin/
echo tareas > /opt/lab/.repo-defecto

# --- Mirrors internos: wheels de PyPI y caché de npm (sin internet) -----------
printf '[global]\nno-index = true\nfind-links = /opt/wheels\ndisable-pip-version-check = true\n' > /etc/pip.conf
mkdir -p /usr/local/etc
printf 'cache=/opt/npm-cache\noffline=true\naudit=false\nfund=false\nupdate-notifier=false\n' > /usr/local/etc/npmrc

# --- PostgreSQL: base de producción y base de CI -------------------------------
systemctl enable --now postgresql
for _ in $(seq 1 30); do runuser -u postgres -- pg_isready -q && break; sleep 1; done
runuser -u postgres -- psql -q <<'SQL'
CREATE ROLE tareas LOGIN PASSWORD 'Prod-Tareas-2026';
CREATE DATABASE tareas OWNER tareas;
CREATE ROLE ci LOGIN PASSWORD 'ci';
CREATE DATABASE tareas_test OWNER ci;
SQL

# --- Forja y runner ------------------------------------------------------------
forja_gitea true self
forja_espejo_checkout
forja_runner self-hosted:host
forja_sin_internet   # desde aquí, nada sale a internet

# --- Producción: servicio tareas + nginx + script de despliegue -----------------
id tareas >/dev/null 2>&1 || useradd --system --no-create-home --shell /usr/sbin/nologin tareas
mkdir -p /srv/tareas/releases /etc/tareas
echo 'DATABASE_URL=postgresql://tareas:Prod-Tareas-2026@127.0.0.1:5432/tareas' > /etc/tareas/env
chmod 600 /etc/tareas/env
cat > /etc/systemd/system/tareas.service <<'U'
[Unit]
Description=API de tareas (FastAPI)
After=network.target postgresql.service
[Service]
User=tareas
EnvironmentFile=/etc/tareas/env
WorkingDirectory=/srv/tareas/current/backend
ExecStart=/srv/tareas/current/venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000
Restart=always
[Install]
WantedBy=multi-user.target
U
cat > /usr/local/bin/desplegar-tareas <<'SH'
#!/usr/bin/env bash
# desplegar-tareas DIR SHA — despliega DIR/backend (con DIR/backend/static si existe)
# como release SHA: venv propio, enlace current atómico, reinicio y prueba de salud.
# El pipeline lo llama con sudo (regla en /etc/sudoers.d/act-runner).
set -euo pipefail
SRC=$1; SHA=$2
[[ $SHA =~ ^[0-9a-f]{40}$ ]] || { echo "SHA no válido: $SHA"; exit 2; }
[ -f "$SRC/backend/app/main.py" ] || { echo "no hay backend en $SRC"; exit 2; }
DEST=/srv/tareas/releases/$SHA
rm -rf "$DEST"; mkdir -p "$DEST"
cp -r "$SRC/backend" "$DEST/"
rm -rf "$DEST/backend/tests" "$DEST/backend/.pytest_cache" "$DEST/backend/.ruff_cache"
echo "$SHA" > "$DEST/VERSION"
[ -f "$DEST/backend/static/index.html" ] && echo "frontend: incluido" || echo "frontend: NO incluido (backend/static vacío)"
python3 -m venv "$DEST/venv"
"$DEST/venv/bin/pip" install -q -r "$DEST/backend/requirements.txt"
chmod -R a+rX "$DEST"
ln -sfn "$DEST" /srv/tareas/.current.tmp && mv -T /srv/tareas/.current.tmp /srv/tareas/current
systemctl restart tareas
for _ in $(seq 1 30); do
  if curl -fs http://127.0.0.1:8000/api/salud | grep -q "$SHA"; then
    echo "desplegado ${SHA:0:8}"
    ls -1dt /srv/tareas/releases/*/ | tail -n +6 | xargs -r rm -rf
    exit 0
  fi
  sleep 1
done
echo "la versión ${SHA:0:8} no responde en /api/salud"; journalctl -u tareas -n 20 --no-pager; exit 1
SH
chmod 755 /usr/local/bin/desplegar-tareas
echo 'act-runner ALL=(root) NOPASSWD: /usr/local/bin/desplegar-tareas' > /etc/sudoers.d/act-runner
chmod 440 /etc/sudoers.d/act-runner
cat > /etc/nginx/sites-available/default <<'NG'
server {
    listen 8080 default_server;
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
    }
}
NG
systemctl enable tareas >/dev/null 2>&1
systemctl enable --now nginx

# --- Repo analista/tareas ------------------------------------------------------
R=/tmp/tareas
mkdir -p $R/backend/app $R/backend/tests $R/frontend/src $R/.github/workflows
cat > $R/backend/requirements.txt <<'TXT'
fastapi==0.115.6
uvicorn==0.34.0
psycopg[binary]==3.2.3
TXT
cat > $R/backend/requirements-dev.txt <<'TXT'
-r requirements.txt
pytest==8.3.4
httpx==0.28.1
ruff==0.8.4
TXT
cat > $R/backend/pyproject.toml <<'TOML'
[tool.ruff]
line-length = 110

[tool.pytest.ini_options]
testpaths = ["tests"]
TOML
touch $R/backend/app/__init__.py
cat > $R/backend/app/main.py <<'PY'
"""API de tareas: FastAPI + PostgreSQL. Sirve también el frontend (backend/static)."""
import os
from contextlib import asynccontextmanager
from pathlib import Path

import psycopg
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

DATABASE_URL = os.environ.get("DATABASE_URL", "")
RAIZ = Path(__file__).resolve().parents[2]
STATIC = Path(__file__).resolve().parents[1] / "static"


def conexion():
    return psycopg.connect(DATABASE_URL, autocommit=True)


def version():
    f = RAIZ / "VERSION"
    return f.read_text().strip() if f.exists() else "dev"


@asynccontextmanager
async def lifespan(app):
    with conexion() as c:
        c.execute("""CREATE TABLE IF NOT EXISTS tareas (
                       id serial PRIMARY KEY,
                       titulo text NOT NULL,
                       hecha boolean NOT NULL DEFAULT false)""")
    yield


app = FastAPI(title="tareas", lifespan=lifespan)


class Nueva(BaseModel):
    titulo: str


def fila(r):
    return {"id": r[0], "titulo": r[1], "hecha": r[2]}


@app.get("/api/salud")
def salud():
    with conexion() as c:
        c.execute("SELECT 1")
    return {"estado": "ok", "version": version()}


@app.get("/api/tareas")
def listar():
    with conexion() as c:
        return [fila(r) for r in c.execute("SELECT id, titulo, hecha FROM tareas ORDER BY id")]


@app.post("/api/tareas", status_code=201)
def crear(n: Nueva):
    titulo = n.titulo.strip()
    if not titulo:
        raise HTTPException(422, "el título no puede estar vacío")
    with conexion() as c:
        r = c.execute("INSERT INTO tareas (titulo) VALUES (%s) RETURNING id, titulo, hecha", (titulo,)).fetchone()
    return fila(r)


@app.post("/api/tareas/{tarea_id}/hecha")
def marcar_hecha(tarea_id: int):
    with conexion() as c:
        r = c.execute("UPDATE tareas SET hecha = true WHERE id = %s RETURNING id, titulo, hecha",
                      (tarea_id,)).fetchone()
    if r is None:
        raise HTTPException(404, f"la tarea {tarea} no existe")
    return fila(r)


if STATIC.is_dir():
    app.mount("/", StaticFiles(directory=STATIC, html=True), name="front")
PY
cat > $R/backend/tests/test_api.py <<'PY'
import os

import psycopg
import pytest

pytestmark = pytest.mark.skipif(not os.environ.get("DATABASE_URL"),
                                reason="sin DATABASE_URL: no hay base de datos de pruebas")


@pytest.fixture
def cliente():
    from fastapi.testclient import TestClient

    from app.main import app
    with TestClient(app) as c:
        with psycopg.connect(os.environ["DATABASE_URL"], autocommit=True) as conn:
            conn.execute("TRUNCATE tareas RESTART IDENTITY")
        yield c


def test_salud(cliente):
    r = cliente.get("/api/salud")
    assert r.status_code == 200 and r.json()["estado"] == "ok"


def test_crear_y_listar(cliente):
    assert cliente.post("/api/tareas", json={"titulo": "  Revisar backups "}).status_code == 201
    assert cliente.get("/api/tareas").json() == [{"id": 1, "titulo": "Revisar backups", "hecha": False}]


def test_titulo_vacio(cliente):
    assert cliente.post("/api/tareas", json={"titulo": "   "}).status_code == 422


def test_marcar_hecha(cliente):
    cliente.post("/api/tareas", json={"titulo": "Rotar claves"})
    assert cliente.post("/api/tareas/1/hecha").json()["hecha"] is True
PY
cp /opt/front-plantilla/package.json /opt/front-plantilla/package-lock.json $R/frontend/
cat > $R/frontend/index.html <<'HTML'
<!doctype html>
<html lang="es">
  <head><meta charset="utf-8"><title>Tareas</title></head>
  <body>
    <h1>Tareas del equipo</h1>
    <form id="nueva"><input name="titulo" placeholder="Nueva tarea" required> <button>Añadir</button></form>
    <ul id="lista"></ul>
    <footer>versión <span id="version">?</span></footer>
    <script type="module" src="/src/main.js"></script>
  </body>
</html>
HTML
cat > $R/frontend/src/main.js <<'JS'
const api = (ruta, opciones) => fetch(`/api${ruta}`, opciones).then((r) => r.json());

async function pintar() {
  const tareas = await api('/tareas');
  document.getElementById('lista').innerHTML = tareas
    .map((t) => `<li>${t.hecha ? '✔' : '◻'} ${t.titulo.replace(/</g, '&lt;')}</li>`)
    .join('');
  document.getElementById('version').textContent = (await api('/salud')).version.slice(0, 8);
}

document.getElementById('nueva').addEventListener('submit', async (e) => {
  e.preventDefault();
  const titulo = e.target.titulo.value;
  await api('/tareas', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ titulo }) });
  e.target.reset();
  pintar();
});

pintar();
JS
printf 'node_modules/\ndist/\n.venv/\n__pycache__/\nbackend/static/\n' > $R/.gitignore
cat > $R/.github/workflows/ci.yml <<'YML'
name: ci
on: push

jobs:
  todo:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4

      - name: Dependencias
        run: |
          python3 -m venv .venv
          .venv/bin/pip install -r backend/requirements-dev.txt

      - name: Tests
        run: cd backend && ../.venv/bin/pytest -v
        continue-on-error: true   # "a veces fallan por la base de datos"

      - name: Desplegar
        run: sudo /usr/local/bin/desplegar-tareas "$PWD" "${{ github.sha }}"
YML
cat > $R/README.md <<'MD'
# tareas

Backend FastAPI (`backend/`) + frontend Vite (`frontend/`), PostgreSQL.

- Local: `cd frontend && npm ci && npm run build`, copia `frontend/dist` a `backend/static`.
- Tests: necesitan `DATABASE_URL` apuntando a una base de pruebas.
- Despliegue: `sudo desplegar-tareas <dir-del-repo> <sha>` (lo hace el pipeline).
MD
forja_repo tareas $R "tareas: backend, frontend y pipeline" "$(date -d '-2 days' -Iseconds)"
SHA=$(git -C $R rev-parse HEAD)
rm -rf $R
echo "Primer pipeline: $(forja_espera_sha tareas "$SHA" 300)"

runuser -u analista -- git clone -q "$GITEA_URL/analista/tareas.git" /home/analista/tareas
runuser -u analista -- git -C /home/analista/tareas config user.name analista
runuser -u analista -- git -C /home/analista/tareas config user.email analista@empresa.local
printf 'machine localhost login analista password analista123\n' > /home/analista/.netrc
chown analista:analista /home/analista/.netrc && chmod 600 /home/analista/.netrc

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Pipeline full stack (Python)

El pipeline de ~/tareas sale en verde siempre. Demasiado verde:
  - los tests no se ejecutan (míralos en ci-log: "skipped"),
  - nadie pasa un linter, y en producción hay un 500 donde debería haber un 404,
  - el frontend no se construye: http://localhost:8080/ devuelve 404,
  - despliega desde cualquier rama.

Datos:
  - Base de datos para CI: postgresql://ci:ci@127.0.0.1:5432/tareas_test
    (aquí no hay Docker: "services: postgres" de GitHub no funciona).
  - Linter: ruff (ya está en requirements-dev.txt).
  - Frontend: Vite. npm funciona sin internet (caché interna): npm ci && npm run build.
  - Despliegue: sudo /usr/local/bin/desplegar-tareas <dir> <sha> (sirve backend/static).

Probar en esta terminal (aquí no hay pytest/ruff instalados ni comando "python"):
  cd ~/tareas && python3 -m venv .venv
  .venv/bin/pip install -r backend/requirements-dev.txt     # sin internet: mirror /opt/wheels
  cd backend && DATABASE_URL=postgresql://ci:ci@127.0.0.1:5432/tareas_test ../.venv/bin/pytest -v
  ../.venv/bin/ruff check .

Ayudas: ci-estado, ci-log [nº], journalctl -u tareas
Comprueba: bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 214 plantado."
