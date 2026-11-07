#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml HOME=/root
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
C=/home/analista/charts/tienda

echo "== Lab 164 · Helm — comprobación =="

# 1) prod: último cambio = rollback, imagen buena y réplicas listas
LAST=$(helm -n prod history tienda --max 1 -o json 2>/dev/null)
IMG=$(kubectl -n prod get deploy tienda-web -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null)
RD=$(kubectl -n prod get deploy tienda-web -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
UPD=$(kubectl -n prod get deploy tienda-web -o jsonpath='{.status.updatedReplicas}' 2>/dev/null)
if echo "$LAST" | grep -qi '"description":"Rollback' && [ "$IMG" = nginx:1.27-alpine ] \
   && [ "${RD%/*}" = "${RD#*/}" ] && [ "${RD%/*}" = "$UPD" ]; then
  ok "prod: rollback hecho, imagen $IMG y réplicas $RD listas."
else
  no "prod: haz 'helm -n prod rollback tienda <rev buena>' (imagen ahora: '$IMG', listas: $RD)."
fi

# 2) Chart parametrizado y lint limpio
if helm lint "$C" >/tmp/lint164.log 2>&1; then
  R4=$(helm template t "$C" --set replicaCount=4 2>/dev/null | grep -cE '^\s*replicas:\s*4\s*$')
  MSG=$(helm template t "$C" --set mensaje=PRUEBA-164 2>/dev/null | grep -c 'PRUEBA-164')
  DEF=$(helm template t "$C" 2>/dev/null)
  if [ "$R4" = 1 ] && [ "$MSG" -ge 1 ] && echo "$DEF" | grep -qE '^\s*replicas:\s*2\s*$' \
     && echo "$DEF" | grep -q 'Bienvenido a la tienda'; then
    ok "Chart parametrizado (replicaCount, mensaje) con valores por defecto y lint limpio."
  else
    no "El chart no usa .Values.replicaCount / .Values.mensaje (o faltan los valores por defecto en values.yaml)."
  fi
else
  no "helm lint falla: $(grep -m1 -iE 'error' /tmp/lint164.log)"
fi

# 3) Ficheros de valores por ambiente
STG=$(helm template t "$C" -f "$C/values-staging.yaml" 2>/dev/null)
PRD=$(helm template t "$C" -f "$C/values-prod.yaml" 2>/dev/null)
if echo "$STG" | grep -qE '^\s*replicas:\s*1\s*$' && echo "$STG" | grep -qi staging \
   && echo "$PRD" | grep -qE '^\s*replicas:\s*2\s*$'; then
  ok "values-staging.yaml (1 réplica, mensaje staging) y values-prod.yaml (2 réplicas)."
else
  no "Crea values-staging.yaml (replicaCount: 1, mensaje con 'staging') y values-prod.yaml (replicaCount: 2)."
fi

# 4) Release en staging
ST=$(helm -n staging status tienda -o json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["info"]["status"])' 2>/dev/null)
SR=$(kubectl -n staging get deploy tienda-web -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null)
HTML=$(kubectl -n staging get configmap tienda-web -o jsonpath='{.data.index\.html}' 2>/dev/null)
if [ "$ST" = deployed ] && [ "$SR" = 1/1 ] && echo "$HTML" | grep -qi staging; then
  ok "staging: release 'tienda' desplegada, 1/1 lista, portada de staging."
else
  no "staging: instala 'tienda' en el namespace staging con -f values-staging.yaml (estado '$ST', réplicas '$SR')."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Un chart, dos ambientes y un rollback en un comando."; exit 0; } || exit 1
