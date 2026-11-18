# Funciones comunes de la pista Q (CI/CD): Gitea con Actions, espejo interno de
# actions/checkout y act_runner en modo host. Se carga con `source` desde plant.sh.
# Idéntico en todos los labs de la pista Q.

[ -r /opt/lab/forja.env ] && . /opt/lab/forja.env
GITEA_PORT=${GITEA_PORT:-3000}
GITEA_URL="http://localhost:$GITEA_PORT"
GITEA_WORK=/var/lib/gitea
GITEA_ADMIN=analista
GITEA_PASS=analista123

# forja_gitea ACTIONS_ENABLED DEFAULT_ACTIONS_URL
forja_gitea() {
  local enabled=${1:-true} actions_url=${2:-self}
  id git >/dev/null 2>&1 || useradd -r -m -d /home/git -s /bin/bash git
  mkdir -p $GITEA_WORK/custom $GITEA_WORK/data $GITEA_WORK/log /etc/gitea
  cat > /etc/gitea/app.ini <<INI
APP_NAME = Gitea · forja interna
RUN_USER = git
RUN_MODE = prod
WORK_PATH = $GITEA_WORK

[server]
HTTP_ADDR = 0.0.0.0
HTTP_PORT = $GITEA_PORT
ROOT_URL = $GITEA_URL/
DISABLE_SSH = true
OFFLINE_MODE = true

[database]
DB_TYPE = sqlite3
PATH = $GITEA_WORK/data/gitea.db

[repository]
ROOT = $GITEA_WORK/data/gitea-repositories

[security]
INSTALL_LOCK = true
SECRET_KEY = $(gitea generate secret SECRET_KEY)
INTERNAL_TOKEN = $(gitea generate secret INTERNAL_TOKEN)

[service]
DISABLE_REGISTRATION = true

[actions]
ENABLED = $enabled
DEFAULT_ACTIONS_URL = $actions_url
LOG_COMPRESSION = none

[log]
MODE = console
LEVEL = warn
INI
  chown -R git:git $GITEA_WORK /etc/gitea
  cat > /etc/systemd/system/gitea.service <<'U'
[Unit]
Description=Gitea (forja git con Actions)
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
  runuser -u git -- gitea admin user create -c /etc/gitea/app.ini --admin --username $GITEA_ADMIN \
    --password $GITEA_PASS --email analista@empresa.local --must-change-password=false >/dev/null
  systemctl daemon-reload
  systemctl enable --now gitea
  forja_espera
}

forja_espera() {
  for _ in $(seq 1 90); do curl -fs "$GITEA_URL/api/healthz" >/dev/null && return 0; sleep 1; done
  echo "Gitea no arrancó"; return 1
}

# forja_api METODO RUTA [JSON]
forja_api() {
  curl -fsS -u "$GITEA_ADMIN:$GITEA_PASS" -H 'Content-Type: application/json' \
    -X "$1" ${3:+-d "$3"} "$GITEA_URL/api/v1$2"
}

# Espejo interno de actions/checkout (org "actions"), para DEFAULT_ACTIONS_URL = self.
forja_espejo_checkout() {
  forja_api POST /orgs '{"username":"actions","visibility":"public"}' >/dev/null
  forja_api POST /orgs/actions/repos '{"name":"checkout","private":false,"default_branch":"main"}' >/dev/null
  git -C /opt/mirrors/checkout.git push -q \
    "http://$GITEA_ADMIN:$GITEA_PASS@localhost:$GITEA_PORT/actions/checkout.git" \
    'refs/heads/main:refs/heads/main' 'refs/tags/*:refs/tags/*' 2>&1 | tail -2
  # Gitea procesa cada ref en una cola asíncrona: si se reinicia antes de acabar,
  # los repos que vengan detrás se quedan marcados como vacíos y Actions los ignora.
  local n
  n=$(git -C /opt/mirrors/checkout.git tag | wc -l)
  for _ in $(seq 1 180); do
    [ "$(curl -fsSI -u "$GITEA_ADMIN:$GITEA_PASS" "$GITEA_URL/api/v1/repos/actions/checkout/tags?limit=1"          | tr -d '
' | sed -n 's/^[Xx]-[Tt]otal-[Cc]ount: //p')" -ge "$n" ] 2>/dev/null && break
    sleep 1
  done
}

# forja_espera_repo OWNER/REPO — espera a que Gitea termine de procesar el push.
forja_espera_repo() {
  for _ in $(seq 1 120); do
    forja_api GET "/repos/$1" 2>/dev/null | python3 -c 'import json,sys;sys.exit(json.load(sys.stdin).get("empty") is not False)' && return 0
    sleep 1
  done
  echo "Gitea no procesó el push de $1"; return 1
}

# forja_repo NOMBRE DIRECTORIO_CON_EL_CONTENIDO "mensaje" [fecha]
# Crea analista/NOMBRE y sube el contenido como primer commit en main.
forja_repo() {
  local name=$1 dir=$2 msg=${3:-"Primer commit"} date=${4:-}
  forja_api POST /user/repos "{\"name\":\"$name\",\"private\":false,\"default_branch\":\"main\"}" >/dev/null
  (
    cd "$dir"
    git init -q -b main
    git config user.name "Equipo plataforma"; git config user.email plataforma@empresa.local
    git add -A
    GIT_AUTHOR_DATE=$date GIT_COMMITTER_DATE=$date git commit -qm "$msg"
    git push -q "http://$GITEA_ADMIN:$GITEA_PASS@localhost:$GITEA_PORT/$GITEA_ADMIN/$name.git" main
  )
  forja_espera_repo "$GITEA_ADMIN/$name"
}

# forja_commit DIRECTORIO "mensaje" — commit y push de lo que haya cambiado.
forja_commit() {
  ( cd "$1" && git add -A && git commit -qm "$2" && \
    git push -q "http://$GITEA_ADMIN:$GITEA_PASS@localhost:$GITEA_PORT/$GITEA_ADMIN/$(basename "$1").git" main )
}

# forja_runner ETIQUETAS — act_runner en modo host, como usuario act-runner, servicio systemd.
forja_runner() {
  local labels=${1:-self-hosted:host}
  id act-runner >/dev/null 2>&1 || useradd -r -m -d /var/lib/act_runner -s /bin/bash act-runner
  mkdir -p /etc/act_runner
  act_runner generate-config > /etc/act_runner/config.yaml
  LABELS="$labels" python3 - <<'PY'
import os, yaml
p = "/etc/act_runner/config.yaml"
c = yaml.safe_load(open(p))
c["runner"]["file"] = "/var/lib/act_runner/.runner"
c["runner"]["capacity"] = 1
c["runner"]["timeout"] = "30m"
c["runner"]["labels"] = os.environ["LABELS"].split(",")
c["cache"]["enabled"] = False
c.setdefault("host", {})["workdir_parent"] = "/var/lib/act_runner/trabajo"
yaml.safe_dump(c, open(p, "w"), sort_keys=False)
PY
  local tok
  tok=$(runuser -u git -- gitea --config /etc/gitea/app.ini actions generate-runner-token 2>/dev/null | tail -1)
  runuser -u act-runner -- act_runner register --no-interactive --config /etc/act_runner/config.yaml \
    --instance "$GITEA_URL" --token "$tok" --name runner-1 >/dev/null
  cat > /etc/systemd/system/act_runner.service <<'U'
[Unit]
Description=Gitea act_runner (ejecuta los workflows de Actions)
After=gitea.service
Wants=gitea.service
[Service]
User=act-runner
Group=act-runner
WorkingDirectory=/var/lib/act_runner
ExecStart=/usr/local/bin/act_runner daemon --config /etc/act_runner/config.yaml
Restart=always
RestartSec=3
[Install]
WantedBy=multi-user.target
U
  systemctl daemon-reload
  systemctl enable --now act_runner
}

# Estados de action_run en Gitea.
FORJA_ESTADOS="1:ok 2:fallo 3:cancelado 4:omitido 5:esperando 6:corriendo 7:bloqueado"

# forja_ejecuciones REPO [N] — últimas ejecuciones de Actions: id|n|estado|rama|sha|título
# (Gitea 1.22 no tiene API de ejecuciones: se lee su base de datos).
forja_ejecuciones() {
  sqlite3 -cmd '.timeout 5000' -separator '|' $GITEA_WORK/data/gitea.db "
    SELECT r.id, r.\"index\", r.status, replace(r.ref,'refs/heads/',''), r.commit_sha, r.title
    FROM action_run r JOIN repository p ON p.id = r.repo_id
    WHERE p.lower_name = lower('$1') ORDER BY r.id DESC LIMIT ${2:-1};" 2>/dev/null
}

# forja_estado_sha REPO SHA — estado (ok, fallo...) de la última ejecución de ese commit.
forja_estado_sha() {
  local st
  st=$(sqlite3 -cmd '.timeout 5000' $GITEA_WORK/data/gitea.db "
    SELECT r.status FROM action_run r JOIN repository p ON p.id = r.repo_id
    WHERE p.lower_name = lower('$1') AND r.commit_sha = '$2' ORDER BY r.id DESC LIMIT 1;" 2>/dev/null)
  for e in $FORJA_ESTADOS; do [ "${e%%:*}" = "$st" ] && { echo "${e#*:}"; return; }; done
  echo "ninguna"
}

# forja_log_sha REPO SHA — logs (todos los jobs) de la última ejecución de ese commit.
forja_log_sha() {
  sqlite3 -cmd '.timeout 5000' $GITEA_WORK/data/gitea.db "
    SELECT t.log_filename FROM action_task t
    JOIN action_run_job j ON j.id = t.job_id
    WHERE j.run_id = (SELECT max(r.id) FROM action_run r JOIN repository p ON p.id = r.repo_id
                      WHERE p.lower_name = lower('$1') AND r.commit_sha = '$2')
    ORDER BY t.id;" 2>/dev/null | while read -r f; do
    [ -f "$GITEA_WORK/data/actions_log/$f" ] && sed -E 's/^[0-9T:.-]+Z //' "$GITEA_WORK/data/actions_log/$f"
  done
}

# forja_espera_sha REPO SHA [segundos] — espera a que termine la ejecución de ese commit.
forja_espera_sha() {
  local e
  for _ in $(seq 1 "${3:-300}"); do
    e=$(forja_estado_sha "$1" "$2")
    case $e in ok|fallo|cancelado|omitido) echo "$e"; return 0;; esac
    sleep 1
  done
  echo "$e"; return 1
}

# forja_sin_internet — el servidor de CI no resuelve nombres de internet: todo
# (acciones, paquetes) tiene que salir de los mirrors internos. Al final de plant.sh.
forja_sin_internet() {
  printf '# Sin DNS externo: servidor de CI aislado (usa los mirrors internos).\nnameserver 127.0.0.1\noptions timeout:1 attempts:1\n' > /etc/resolv.conf
}
