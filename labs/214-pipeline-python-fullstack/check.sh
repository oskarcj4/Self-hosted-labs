#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
source /opt/lab/forja.sh
BARE=$GITEA_WORK/data/gitea-repositories/analista/tareas.git
HEAD=$(git --git-dir "$BARE" rev-parse main 2>/dev/null)

echo "== Lab 214 · Pipeline full stack Python — comprobación =="

EST=$(forja_estado_sha tareas "$HEAD")
case $EST in corriendo|esperando|bloqueado)
  echo "  (el pipeline de ${HEAD:0:8} sigue en marcha: esperando hasta 3 min...)"
  EST=$(forja_espera_sha tareas "$HEAD" 180);;
esac
LOG=$(forja_log_sha tareas "$HEAD")
if [ "$EST" = ok ]; then
  ok "El pipeline del último commit de main (${HEAD:0:8}) está en verde."
else
  no "El pipeline de ${HEAD:0:8} está '$EST' (ci-estado, ci-log)."
fi

# Tests de verdad: contra PostgreSQL, ninguno saltado.
PASADOS=$(printf '%s\n' "$LOG" | grep -oE '[0-9]+ passed' | tail -1 | grep -oE '^[0-9]+')
if [ "${PASADOS:-0}" -ge 4 ] && ! printf '%s\n' "$LOG" | grep -qE '[0-9]+ skipped'; then
  ok "Los tests se ejecutan contra PostgreSQL ($PASADOS pasados, ninguno saltado)."
else
  no "En el log del pipeline no hay tests ejecutados (pasados: ${PASADOS:-0}; ¿siguen 'skipped'? falta DATABASE_URL)."
fi
if printf '%s\n' "$LOG" | grep -q 'All checks passed!'; then
  ok "ruff pasa en el pipeline."
else
  no "El pipeline no pasa ruff (o no lo ejecuta): falta 'ruff check backend' en verde."
fi

# Estructura del workflow: sin continue-on-error, despliegue sólo tras los tests y sólo desde main.
export BARE
WF=$(python3 - <<'PY'
import json, os, subprocess, yaml
bare = os.environ["BARE"]
def git(*a):
    return subprocess.run(["git", "--git-dir", bare, *a], capture_output=True, text=True).stdout
files = [f for f in git("ls-tree", "-r", "--name-only", "main").split("\n")
         if f.startswith((".github/workflows/", ".gitea/workflows/")) and f.endswith((".yml", ".yaml"))]
res = {"coe": False, "orden": False, "rama": False, "front": False}
for f in files:
    try:
        wf = yaml.safe_load(git("show", f"main:{f}")) or {}
    except Exception:
        continue
    on = wf.get("on", wf.get(True))
    jobs = wf.get("jobs") or {}
    if "continue-on-error" in yaml.safe_dump(wf):
        res["coe"] = True
    def txt(x): return yaml.safe_dump(x)
    def antes(nombre, vistos=None):
        """Jobs de los que depende 'nombre' (transitivo)."""
        vistos = vistos or set()
        n = jobs.get(nombre, {}).get("needs") or []
        for d in [n] if isinstance(n, str) else n:
            if d not in vistos:
                vistos.add(d); antes(d, vistos)
        return vistos
    for jn, j in jobs.items():
        steps = j.get("steps") or []
        idx = [i for i, s in enumerate(steps) if "desplegar-tareas" in txt(s)]
        if not idx:
            continue
        d = idx[0]
        cond = str(j.get("if", "")) + str(steps[d].get("if", ""))
        if "always()" in cond or "failure()" in cond:
            continue
        pytest_aqui = any("pytest" in txt(s) for s in steps[:d])
        pytest_antes = any("pytest" in txt(jobs[x]) for x in antes(jn) if x in jobs)
        res["orden"] = pytest_aqui or pytest_antes
        res["front"] = any("npm run build" in txt(s) or "vite build" in txt(s) for s in steps[:d]) \
            or any("npm run build" in txt(jobs[x]) for x in antes(jn) if x in jobs)
        p = on.get("push") if isinstance(on, dict) else None
        solo = isinstance(on, dict) and not (set(on) - {"push", "workflow_dispatch"}) \
            and isinstance(p, dict) and p.get("branches") in (["main"], "main")
        res["rama"] = solo or ("refs/heads/main" in cond and "==" in cond)
print(json.dumps(res))
PY
)
j(){ python3 -c 'import json,sys;print(json.loads(sys.argv[1]).get(sys.argv[2]))' "$WF" "$1"; }
if [ "$(j coe)" = False ] && [ "$(j orden)" = True ]; then
  ok "El despliegue sólo ocurre si los tests pasan (sin continue-on-error)."
else
  no "Se puede desplegar con tests en rojo (continue-on-error, o el despliegue no depende de los tests)."
fi
if [ "$(j rama)" = True ]; then
  ok "Sólo se despliega desde main."
else
  no "El workflow despliega desde cualquier rama."
fi

# Producción.
SALUD=$(curl -fs http://127.0.0.1:8080/api/salud 2>/dev/null)
if printf '%s' "$SALUD" | grep -q "$HEAD"; then
  ok "Producción corre el último commit de main (${HEAD:0:8})."
else
  no "Producción no corre ${HEAD:0:8} (/api/salud: ${SALUD:-sin respuesta})."
fi
INDEX=$(curl -fs http://127.0.0.1:8080/ 2>/dev/null)
ASSET=$(printf '%s' "$INDEX" | grep -oE '/assets/index-[A-Za-z0-9_-]+\.js' | head -1)
if [ "$(j front)" = True ] && [ -n "$ASSET" ] && curl -fs "http://127.0.0.1:8080$ASSET" >/dev/null; then
  ok "El pipeline construye el frontend y producción lo sirve ($ASSET)."
else
  no "Producción no sirve el frontend construido por Vite en / (o el pipeline no ejecuta npm run build)."
fi
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST http://127.0.0.1:8080/api/tareas/987654/hecha)
if [ "$CODE" = 404 ]; then
  ok "Marcar una tarea que no existe devuelve 404."
else
  no "POST /api/tareas/987654/hecha devuelve $CODE, no 404 (journalctl -u tareas)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Verde de verdad: lint, tests con base de datos, frontend y despliegue sólo desde main."; exit 0; } || exit 1
