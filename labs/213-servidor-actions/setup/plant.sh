#!/usr/bin/env bash
# Lab 213: montar tu propio "GitHub Actions" (Gitea Actions + act_runner).
# Plantado:
#  - Gitea en :4213 con Actions DESACTIVADO y DEFAULT_ACTIONS_URL=github (sin internet
#    no puede bajar actions/checkout). El espejo interno actions/checkout ya existe.
#  - act_runner instalado (binario) pero sin registrar ni servicio.
#  - Repo analista/web con un workflow que: corre en ubuntu-latest (no hay Docker),
#    despliega desde cualquier rama y lleva un token de despliegue (revocado) en claro.
#  - Receptor de despliegues en :9000 (token en /etc/deployer/token) y nginx en :8080
#    que sirve /srv/www/current.
set -e
export HOME=/root
echo GITEA_PORT=4213 > /opt/lab/forja.env
source /opt/lab/setup/forja.sh
install -m 0644 /opt/lab/setup/forja.sh /opt/lab/forja.sh

# --- Gitea (Actions apagado, acciones de github.com) --------------------------
forja_gitea false github
# El espejo se sube con Actions apagado: la API de repos funciona igual.
forja_espejo_checkout
forja_sin_internet   # desde aquí, nada sale a internet

# --- Producción: receptor de despliegues + nginx ------------------------------
mkdir -p /etc/deployer /srv/www/releases /opt/deployer
TOKEN="dpl_$(tr -dc 'a-z0-9' < /dev/urandom | head -c 28)"
echo "$TOKEN" > /etc/deployer/token
chmod 600 /etc/deployer/token
cat > /opt/deployer/receptor.py <<'PY'
#!/usr/bin/env python3
"""Receptor de despliegues: POST /deploy con un .tar.gz del sitio.

Cabeceras: Authorization: Bearer <token>, X-Commit: <sha completo>.
Extrae en /srv/www/releases/<sha> y cambia el enlace /srv/www/current de forma atómica.
"""
import http.server, io, json, os, re, tarfile, time

TOKEN = open("/etc/deployer/token").read().strip()
WWW = "/srv/www"
LOG = "/var/log/deployer.log"


def log(**d):
    with open(LOG, "a") as f:
        f.write(json.dumps({"ts": time.strftime("%Y-%m-%dT%H:%M:%S"), **d}) + "\n")


class H(http.server.BaseHTTPRequestHandler):
    def responde(self, code, msg):
        self.send_response(code)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.end_headers()
        self.wfile.write((msg + "\n").encode())

    def do_POST(self):
        if self.path != "/deploy":
            return self.responde(404, "no existe")
        if self.headers.get("Authorization", "") != f"Bearer {TOKEN}":
            log(resultado="401", commit=self.headers.get("X-Commit"))
            return self.responde(401, "token no válido (¿revocado?)")
        sha = self.headers.get("X-Commit", "")
        if not re.fullmatch(r"[0-9a-f]{40}", sha):
            return self.responde(400, "X-Commit debe ser el SHA completo del commit")
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        dest = f"{WWW}/releases/{sha}"
        os.makedirs(dest, exist_ok=True)
        with tarfile.open(fileobj=io.BytesIO(body), mode="r:gz") as t:
            for m in t.getmembers():
                if m.name.startswith("/") or ".." in m.name.split("/") or not (m.isfile() or m.isdir()):
                    return self.responde(400, f"entrada no permitida en el tar: {m.name}")
            t.extractall(dest)
        tmp = f"{WWW}/.current-{sha}"
        if os.path.lexists(tmp):
            os.unlink(tmp)
        os.symlink(dest, tmp)
        os.replace(tmp, f"{WWW}/current")
        log(resultado="ok", commit=sha)
        self.responde(200, f"desplegado {sha[:8]}")

    def log_message(self, *a):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", 9000), H).serve_forever()
PY
cat > /etc/systemd/system/deployer.service <<'U'
[Unit]
Description=Receptor de despliegues de la web
After=network.target
[Service]
ExecStart=/usr/bin/python3 /opt/deployer/receptor.py
Restart=always
[Install]
WantedBy=multi-user.target
U
# Versión que está ahora en producción (desplegada a mano, hace semanas).
mkdir -p /srv/www/releases/manual
echo '<h1>Web de la empresa</h1><p>Desplegada a mano por FTP.</p>' > /srv/www/releases/manual/index.html
echo manual > /srv/www/releases/manual/VERSION
ln -sfn /srv/www/releases/manual /srv/www/current
cat > /etc/nginx/sites-available/default <<'NG'
server {
    listen 8080 default_server;
    root /srv/www/current;
    index index.html;
    add_header Cache-Control "no-store";
}
NG
systemctl daemon-reload
systemctl enable --now deployer nginx

# --- Repo analista/web ---------------------------------------------------------
R=/tmp/web
mkdir -p $R/site $R/tests $R/.github/workflows
cat > $R/site/index.html <<'HTML'
<!doctype html>
<html lang="es">
<head><meta charset="utf-8"><title>Empresa</title><link rel="stylesheet" href="estilo.css"></head>
<body>
  <h1>Web de la empresa</h1>
  <p>Desplegada por el pipeline. Versión: <span id="v"></span></p>
  <script>fetch('VERSION').then(r => r.text()).then(t => document.getElementById('v').textContent = t.slice(0, 8))</script>
</body>
</html>
HTML
echo 'body{font-family:sans-serif;max-width:40rem;margin:3rem auto}' > $R/site/estilo.css
cat > $R/tests/check-html.sh <<'SH'
#!/usr/bin/env bash
# Pruebas mínimas del sitio: cada .html tiene doctype, <title> y lang.
set -e
fallos=0
for f in site/*.html; do
  grep -qi '<!doctype html>' "$f" || { echo "FALLO $f: sin doctype"; fallos=1; }
  grep -qi '<title>' "$f"         || { echo "FALLO $f: sin <title>"; fallos=1; }
  grep -qi '<html lang=' "$f"     || { echo "FALLO $f: sin lang"; fallos=1; }
done
[ $fallos -eq 0 ] && echo "HTML OK"
exit $fallos
SH
chmod +x $R/tests/check-html.sh
cat > $R/.github/workflows/deploy.yml <<'YML'
# Copiado tal cual de GitHub. "En nuestra forja debería funcionar igual..."
name: deploy
on: push

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Pruebas
        run: ./tests/check-html.sh

      - name: Construir
        run: |
          mkdir -p dist
          cp -r site/* dist/
          echo "${{ github.sha }}" > dist/VERSION

      - name: Desplegar
        run: |
          tar -C dist -czf site.tgz .
          curl -fsS -X POST \
            -H "Authorization: Bearer dpl_7f3a9c1e0b2d4f6a8c0e2b4d6f8a" \
            -H "X-Commit: ${{ github.sha }}" \
            --data-binary @site.tgz http://127.0.0.1:9000/deploy
YML
cat > $R/README.md <<'MD'
# web

Web corporativa. Cada push despliega a producción (http://localhost:8080 en el servidor).
MD
forja_repo web $R "Migración desde GitHub: web + workflow" "$(date -d '-3 days' -Iseconds)"
rm -rf $R

# Clon de trabajo para analista.
runuser -u analista -- git clone -q "http://localhost:$GITEA_PORT/analista/web.git" /home/analista/web
runuser -u analista -- git -C /home/analista/web config user.name analista
runuser -u analista -- git -C /home/analista/web config user.email analista@empresa.local
cat > /home/analista/.netrc <<N
machine localhost login analista password analista123
N
chown analista:analista /home/analista/.netrc && chmod 600 /home/analista/.netrc

# Ayudas: ci-estado y ci-log (leen la base de datos de Gitea).
install -m 0755 /opt/lab/setup/ci-estado /opt/lab/setup/ci-log /usr/local/bin/
echo web > /opt/lab/.repo-defecto

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Nuestro propio GitHub Actions

Nos vamos de GitHub a nuestra forja (Gitea, http://localhost:4213, usuario
analista / analista123). Gitea entiende la sintaxis de GitHub Actions, pero
el servidor está a medio montar:

  - Actions está apagado en /etc/gitea/app.ini.
  - El servidor no tiene internet: las acciones (uses:) deben salir del espejo
    interno (org "actions" en la propia forja), no de github.com.
  - act_runner está instalado (/usr/local/bin/act_runner) pero no registrado.
    No hay Docker en este servidor: el runner ejecuta en modo host.
  - El workflow de ~/web despliega desde CUALQUIER rama y lleva el token de
    despliegue en claro (y encima ya está revocado; el bueno está en
    /etc/deployer/token).

Objetivo: un push a main despliega solo, y la web de producción
(http://localhost:8080 dentro del servidor;
http://localhost:8213 desde tu navegador) muestra el commit de main.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 213 plantado."
