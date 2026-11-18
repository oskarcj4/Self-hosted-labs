#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
source /opt/lab/forja.sh
BARE=$GITEA_WORK/data/gitea-repositories/analista/precios.git
HEAD=$(git --git-dir "$BARE" rev-parse main 2>/dev/null)

echo "== Lab 215 · Pipeline full stack Java — comprobación =="

EST=$(forja_estado_sha precios "$HEAD")
case $EST in corriendo|esperando|bloqueado)
  echo "  (el pipeline de ${HEAD:0:8} sigue en marcha: esperando hasta 3 min...)"
  EST=$(forja_espera_sha precios "$HEAD" 180);;
esac
LOG=$(forja_log_sha precios "$HEAD")
if [ "$EST" = ok ]; then
  ok "El pipeline del último commit de main (${HEAD:0:8}) está en verde."
else
  no "El pipeline de ${HEAD:0:8} está '$EST' (ci-estado, ci-log)."
fi

# Maven sólo habla con el repositorio interno.
if printf '%s\n' "$LOG" | grep -q 'BUILD SUCCESS' \
   && printf '%s\n' "$LOG" | grep -qE 'from [A-Za-z0-9_.-]+: http://(localhost|127\.0\.0\.1):8081' \
   && ! printf '%s\n' "$LOG" | grep -q 'repo.maven.apache.org'; then
  ok "Maven resuelve dependencias del repositorio interno (localhost:8081), no de Maven Central."
elif printf '%s\n' "$LOG" | grep -q 'BUILD SUCCESS' && ! printf '%s\n' "$LOG" | grep -q 'repo.maven.apache.org' \
   && git --git-dir "$BARE" grep -qE 'localhost:8081|127\.0\.0\.1:8081' main -- '*.xml' '.mvn/*' 2>/dev/null; then
  ok "Maven usa el repositorio interno (mirror configurado en el repo)."
else
  no "Maven no compila contra el repositorio interno http://localhost:8081/ (¿mirror en un settings.xml del repo?)."
fi

JV=$(git --git-dir "$BARE" show main:pom.xml 2>/dev/null | python3 -c '
import re, sys
s = sys.stdin.read()
m = re.search(r"<(?:java\.version|maven\.compiler\.release|maven\.compiler\.target)>\s*(\d+)", s)
print(m.group(1) if m else "")')
JDK=$(java -version 2>&1 | sed -n 's/.*version "\([0-9]*\).*/\1/p' | head -1)
if [ -n "$JV" ] && [ "$JV" -le "${JDK:-17}" ]; then
  ok "El pom compila para Java $JV, compatible con el JDK $JDK del servidor."
else
  no "El pom pide Java ${JV:-?} y el servidor tiene JDK $JDK."
fi

# Tests ejecutados.
RES=$(printf '%s\n' "$LOG" | grep -E '^\[?(INFO|WARNING|ERROR)?\]? *Tests run: [0-9]+, Failures: [0-9]+, Errors: [0-9]+, Skipped: [0-9]+$' | tail -1)
[ -n "$RES" ] || RES=$(printf '%s\n' "$LOG" | grep -E 'Tests run: [0-9]+, Failures' | grep -v ' in ' | tail -1)
N=$(printf '%s' "$RES" | sed -n 's/.*Tests run: \([0-9]*\).*/\1/p')
F=$(printf '%s' "$RES" | sed -n 's/.*Failures: \([0-9]*\), Errors: \([0-9]*\).*/\1\2/p')
WF=$(python3 /opt/lab/wf.py "$BARE" desplegar-precios 'mvn' 2>/dev/null)
j(){ python3 -c 'import json,sys;print(json.loads(sys.argv[1] or "{}").get(sys.argv[2]))' "$WF" "$1"; }
if [ "${N:-0}" -ge 5 ] && [ "$F" = 00 ] && ! j previos | grep -qE 'skipTests|maven\.test\.skip'; then
  ok "Los tests se ejecutan en el pipeline ($N tests, 0 fallos)."
else
  no "El pipeline no ejecuta todos los tests (resumen: '${RES:-ninguno}'; ¿-DskipTests?)."
fi
if [ "$(j coe)" = False ] && [ "$(j orden)" = True ] && ! j previos | grep -qE 'skipTests|maven\.test\.skip'; then
  ok "Sólo se despliega un jar que ha pasado los tests."
else
  no "El despliegue no depende de que pasen los tests (skipTests, continue-on-error o falta needs)."
fi
if [ "$(j rama)" = True ]; then
  ok "Sólo se despliega desde main."
else
  no "El workflow despliega desde cualquier rama."
fi

# Producción.
V=$(curl -fs http://127.0.0.1:8080/api/version 2>/dev/null)
if printf '%s' "$V" | grep -q "$HEAD"; then
  ok "Producción corre el último commit de main (${HEAD:0:8}), no un jar hecho a mano."
else
  no "Producción no corre ${HEAD:0:8} (/api/version: ${V:-sin respuesta})."
fi
T=$(curl -fs 'http://127.0.0.1:8080/api/precio?base=19.99&iva=21' 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["total"])' 2>/dev/null)
if [ "$T" = 24.19 ] && curl -fs http://127.0.0.1:8080/ | grep -q 'Calculadora de precios'; then
  ok "La calculadora (frontend + API) suma bien el IVA: 19.99 + 21 % = 24.19."
else
  no "19.99 con 21 % de IVA da '${T:-sin respuesta}' en producción (debe ser 24.19)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Del commit al jar en producción, con tests y sin portátiles."; exit 0; } || exit 1
