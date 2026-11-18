#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
source /opt/lab/forja.sh
BARE=/var/lib/gitea/data/gitea-repositories/analista/web.git
TOKEN=$(cat /etc/deployer/token)

echo "== Lab 213 · Tu propio GitHub Actions — comprobación =="

# 1. Gitea con Actions y acciones del espejo interno.
INI=$(python3 - <<'PY'
import configparser
c = configparser.ConfigParser(strict=False, interpolation=None)
c.read_string("[raiz]\n" + open("/etc/gitea/app.ini").read())
a = c["actions"] if c.has_section("actions") else {}
print(a.get("ENABLED", "true").strip().lower(), a.get("DEFAULT_ACTIONS_URL", "github").strip().lower())
PY
)
read -r ENABLED AURL <<<"$INI"
if [ "$ENABLED" = true ] && systemctl is-active -q gitea && forja_espera >/dev/null 2>&1; then
  ok "Gitea en marcha con Actions activado."
else
  no "Actions no está activado en /etc/gitea/app.ini (o Gitea no está activo tras el cambio)."
fi
if [ "$AURL" = self ]; then
  ok "Las acciones (uses:) salen del espejo interno (DEFAULT_ACTIONS_URL = self)."
else
  no "DEFAULT_ACTIONS_URL = ${AURL:-github}: sin internet, actions/checkout no se puede descargar."
fi

if [ "$(forja_api GET /repos/analista/web 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin).get("has_actions"))' 2>/dev/null)" = True ]; then
  ok "El repo analista/web tiene Actions activado."
else
  no "El repo analista/web no tiene Actions (se creó con Actions apagado: Ajustes del repo → Avanzado)."
fi

# 2. Runner registrado, como servicio y sin root.
RFILE=$(python3 -c 'import yaml;print((yaml.safe_load(open("/etc/act_runner/config.yaml")) or {}).get("runner",{}).get("file") or "")' 2>/dev/null)
WD=$(systemctl show act_runner -p WorkingDirectory --value 2>/dev/null)
[ -n "$RFILE" ] || RFILE=.runner
case "$RFILE" in /*) ;; *) RFILE="${WD:-/}/$RFILE";; esac
RUSER=$(systemctl show act_runner -p User --value 2>/dev/null)
if systemctl is-active -q act_runner && [ -s "$RFILE" ]; then
  ok "act_runner registrado ($RFILE) y activo como servicio."
else
  no "act_runner.service no está activo o no está registrado (falta el fichero .runner)."
fi
if systemctl is-active -q act_runner && [ -n "$RUSER" ] && [ "$RUSER" != root ]; then
  ok "El runner corre como '$RUSER', no como root."
else
  no "El runner corre como root (falta User= en act_runner.service)."
fi

# 3-5. El workflow de main.
export BARE RFILE TOKEN
WF=$(python3 - <<'PY'
import json, os, subprocess, yaml
bare, rfile, token = os.environ["BARE"], os.environ["RFILE"], os.environ["TOKEN"]
def git(*a):
    return subprocess.run(["git", "--git-dir", bare, *a], capture_output=True, text=True).stdout
try:
    labels = {l.split(":")[0] for l in json.load(open(rfile)).get("labels", [])}
except Exception:
    labels = set()
files = [f for f in git("ls-tree", "-r", "--name-only", "main").split("\n")
         if f.startswith((".github/workflows/", ".gitea/workflows/")) and f.endswith((".yml", ".yaml"))]
res = {"runson": False, "rama": False, "secreto": False, "literal": False, "hay": bool(files), "runs_on": []}
for f in files:
    try:
        wf = yaml.safe_load(git("show", f"main:{f}")) or {}
    except Exception:
        continue
    on = wf.get("on", wf.get(True))
    jobs = wf.get("jobs") or {}
    for jn, j in jobs.items():
        steps = j.get("steps") or []
        texto = yaml.safe_dump(j)
        if "9000/deploy" not in texto:
            continue
        ro = j.get("runs-on")
        ro = [ro] if isinstance(ro, str) else list(ro or [])
        res["runs_on"] = ro
        res["runson"] = bool(ro) and set(ro) <= labels
        # Despliegue sólo desde main: por el disparador o por un if en el job/paso.
        def solo_main(on):
            if isinstance(on, dict):
                if set(on) - {"push", "workflow_dispatch"}:
                    return False
                p = on.get("push") or {}
                return isinstance(p, dict) and p.get("branches") in (["main"], "main") and not p.get("branches-ignore")
            return False
        cond = str(j.get("if", "")) + "".join(str(s.get("if", "")) for s in steps if "9000/deploy" in yaml.safe_dump(s))
        res["rama"] = solo_main(on) or ("refs/heads/main" in cond.replace('"', "'") and "==" in cond)
        dep = "".join(yaml.safe_dump(s) for s in steps if "9000/deploy" in yaml.safe_dump(s))
        res["secreto"] = "secrets." in dep
arbol = git("grep", "-I", "-l", "-e", token, "-e", "dpl_7f3a9c1e0b2d4f6a8c0e2b4d6f8a", "main")
res["literal"] = bool(arbol.strip())
print(json.dumps(res))
PY
)
j(){ python3 -c 'import json,sys;print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$WF" "$1"; }
if [ "$(j runson)" = True ]; then
  ok "El job de despliegue pide un runner que existe (runs-on: $(j runs_on))."
else
  no "runs-on: $(j runs_on) no coincide con ninguna etiqueta del runner registrado (mira $RFILE)."
fi
if [ "$(j rama)" = True ]; then
  ok "Sólo se despliega desde main."
else
  no "El workflow despliega desde cualquier rama (o también en pull_request)."
fi
if [ "$(j secreto)" = True ] && [ "$(j literal)" = False ]; then
  ok "El token de despliegue sale de un secreto, no del repo."
else
  no "El paso de despliegue no usa secrets.* o hay un token de despliegue escrito en el repo."
fi

# 6. Producción tiene main.
HEAD=$(git --git-dir "$BARE" rev-parse main 2>/dev/null)
case $(forja_estado_sha web "$HEAD") in corriendo|esperando|bloqueado)
  echo "  (el pipeline de ${HEAD:0:8} sigue en marcha: esperando hasta 3 min...)"
  forja_espera_sha web "$HEAD" 180 >/dev/null;;
esac
VER=$(curl -fs http://127.0.0.1:8080/VERSION 2>/dev/null | tr -d '[:space:]')
if [ -n "$HEAD" ] && [ "$VER" = "$HEAD" ]; then
  ok "Producción sirve el último commit de main (${HEAD:0:8}) desplegado por el pipeline."
else
  no "Producción sirve '${VER:0:12}', y main está en ${HEAD:0:8} (última ejecución de ese commit: $(forja_estado_sha web "$HEAD"); mira ci-estado y ci-log)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Push a main y a producción, sin GitHub y sin tokens en el repo."; exit 0; } || exit 1
