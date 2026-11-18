#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
source /opt/lab/forja.sh
J=/var/lib/jenkins
BARE=$GITEA_WORK/data/gitea-repositories/analista/tienda.git
HEAD=$(git --git-dir "$BARE" rev-parse main 2>/dev/null)
CFG=$J/jobs/tienda/config.xml
JF=$(git --git-dir "$BARE" show main:Jenkinsfile 2>/dev/null)

echo "== Lab 218 · Pipeline de Jenkins desde Gitea — comprobación =="

# 1. El pipeline se versiona en el repo y el job lo lee de Gitea.
CID=$(sed -n 's:.*<credentialsId>\(.*\)</credentialsId>.*:\1:p' "$CFG" 2>/dev/null | head -1)
if grep -q 'CpsScmFlowDefinition' "$CFG" 2>/dev/null && grep -q '<scriptPath>Jenkinsfile</scriptPath>' "$CFG" \
   && grep -q 'localhost:4218/analista/tienda' "$CFG" && grep -q '<name>[^<]*main</name>' "$CFG" && [ -n "$JF" ]; then
  ok "El job tienda lee el Jenkinsfile de main desde Gitea."
else
  no "El job tienda no es 'Pipeline script from SCM' (Gitea, rama main, Jenkinsfile), o main no tiene Jenkinsfile."
fi
if [ -n "$CID" ] && grep -q "<id>$CID</id>" "$J/credentials.xml" 2>/dev/null \
   && ! grep -q 'analista123' "$CFG" && ! printf '%s' "$JF" | grep -q 'analista123'; then
  ok "Gitea se lee con la credencial de Jenkins '$CID', sin contraseñas en claro."
else
  no "El job no usa una credencial de Jenkins existente para Gitea, o la contraseña sigue en claro."
fi

# 2. Webhook de Gitea hacia Jenkins, entregado.
REPO_ID=$(sqlite3 -cmd '.timeout 5000' $GITEA_WORK/data/gitea.db "select id from repository where lower_name='tienda'")
HOOK=$(sqlite3 -cmd '.timeout 5000' $GITEA_WORK/data/gitea.db \
  "select h.id from webhook h where h.repo_id=$REPO_ID and h.is_active=1 and h.url like '%localhost:8080%' order by h.id desc limit 1")
ULT=$( [ -n "$HOOK" ] && sqlite3 -cmd '.timeout 5000' $GITEA_WORK/data/gitea.db \
  "select is_succeed from hook_task where hook_id=$HOOK and is_delivered=1 order by id desc limit 1")
if [ -n "$HOOK" ] && [ "$ULT" = 1 ]; then
  ok "Un webhook de Gitea lanza Jenkins en cada push (última entrega OK)."
else
  no "No hay webhook activo de tienda a Jenkins (http://localhost:8080/...), o su última entrega falló."
fi

# 3. Jenkinsfile: paralelo, JUnit y despliegue condicionado.
if printf '%s' "$JF" | grep -q 'parallel' && printf '%s' "$JF" | grep -q 'junit'; then
  ok "El Jenkinsfile tiene etapas en paralelo y publica JUnit."
else
  no "El Jenkinsfile no usa parallel o no publica el informe con junit."
fi

# 4. Último build: verde, sobre HEAD y con tests.
B=$(ls -1 $J/jobs/tienda/builds 2>/dev/null | grep -E '^[0-9]+$' | sort -n | tail -1)
BX=$J/jobs/tienda/builds/$B/build.xml
for _ in $(seq 1 60); do grep -q '<result>' "$BX" 2>/dev/null && break; sleep 2; done
if [ -n "$B" ] && grep -q '<result>SUCCESS' "$BX" && grep -q "$HEAD" "$BX"; then
  ok "El último build de tienda (#$B) es verde y compiló ${HEAD:0:8}."
else
  no "El último build de tienda no está en verde o no es del último commit de main (${HEAD:0:8})."
fi
TOT=$(sed -n 's:.*<totalCount>\([0-9]*\)</totalCount>.*:\1:p' "$BX" 2>/dev/null | head -1)
FALLOS=$(sed -n 's:.*<failCount>\([0-9]*\)</failCount>.*:\1:p' "$BX" 2>/dev/null | head -1)
if grep -q 'TestResultAction' "$BX" 2>/dev/null && [ "${TOT:-0}" -ge 6 ] && [ "${FALLOS:-1}" = 0 ]; then
  ok "Jenkins tiene el informe de tests: $TOT tests, 0 fallos."
else
  no "El build no tiene informe JUnit con los 6 tests en verde (total ${TOT:-0}, fallos ${FALLOS:-?})."
fi

# 5. Producción.
V=$(curl -fs http://127.0.0.1:9080/api/version 2>/dev/null)
if printf '%s' "$V" | grep -q "$HEAD"; then
  ok "Producción corre el último commit de main (${HEAD:0:8})."
else
  no "Producción no corre ${HEAD:0:8} (/api/version: ${V:-sin respuesta})."
fi
T=$(curl -fs 'http://127.0.0.1:9080/api/total?items=20x2,10x1&descuento=10' 2>/dev/null)
if printf '%s' "$T" | grep -q '"total":45' && curl -fs http://127.0.0.1:9080/ | grep -q 'calculadora del carrito'; then
  ok "El descuento se calcula bien (20x2 + 10x1 con 10% = 45) y el frontend responde."
else
  no "El total con descuento sigue mal o el frontend no responde (${T:-sin respuesta})."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Pipeline como código, webhook, tests publicados y despliegue limpio."; exit 0; } || exit 1
