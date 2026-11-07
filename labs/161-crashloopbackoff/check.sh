#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
NS=tienda
D=/home/analista/diagnostico.txt
ready(){ [ "$(kubectl -n $NS get deploy "$1" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)" = "1" ]; }
restarts(){ kubectl -n $NS get pods -l app="$1" -o jsonpath='{range .items[*]}{.status.containerStatuses[0].restartCount}{" "}{end}' 2>/dev/null; }
# Cantidad de memoria de Kubernetes (128Mi, 1Gi, 100M...) -> MiB enteros.
mib(){ python3 -c '
import sys, re
m = re.fullmatch(r"(\d+(?:\.\d+)?)(Ki|Mi|Gi|K|M|G)?", sys.argv[1].strip())
f = {"": 1/2**20, "Ki": 1/1024, "Mi": 1, "Gi": 1024, "K": 1e3/2**20, "M": 1e6/2**20, "G": 1e9/2**20}
print(int(float(m.group(1)) * f[m.group(2) or ""]) if m else 0)' "$1"; }

echo "== Lab 161 · CrashLoopBackOff — comprobación =="

g(){ grep -iE "^\s*$1\s*=" "$D" 2>/dev/null | head -1 | cut -d= -f2- | tr 'A-Z' 'a-z'; }
if g api | grep -q oom && g worker | grep -qE 'liveness|probe|sonda' && g web | grep -qE 'configmap|config'; then
  ok "Diagnóstico correcto en ~/diagnostico.txt."
else
  no "~/diagnostico.txt debe tener api=oomkilled, worker=liveness, web=configmap."
fi

LIM=$(kubectl -n $NS get deploy api -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
ARGS=$(kubectl -n $NS get deploy api -o jsonpath='{.spec.template.spec.containers[0].args}' 2>/dev/null)
if [ -n "$LIM" ] && [ "$(mib "$LIM")" -ge 80 ] && echo "$ARGS" | grep -q 'head -c 60m' && ready api; then
  ok "api: límite de memoria $LIM (con la carga intacta) y Ready."
else
  no "api: límite de memoria >= 80Mi (~60 MiB de carga + proceso), sin quitar la carga, y Ready."
fi

LP=$(kubectl -n $NS get deploy worker -o jsonpath='{.spec.template.spec.containers[0].livenessProbe.httpGet.port}' 2>/dev/null)
if [ "$LP" = "8080" ] && ready worker; then
  ok "worker: livenessProbe en el puerto 8080 y Ready."
else
  no "worker: la livenessProbe debe ir al puerto 8080 (donde escucha la app). Ahora: '${LP:-ninguna}'."
fi

DBH=$(kubectl -n $NS get configmap web-config -o jsonpath='{.data.DB_HOST}' 2>/dev/null)
if [ "$DBH" = "db.tienda.svc.cluster.local" ] && ready web; then
  ok "web: ConfigMap web-config con DB_HOST y Ready."
else
  no "web: crea el ConfigMap web-config con DB_HOST=db.tienda.svc.cluster.local y reinicia el Deployment."
fi

R1="$(restarts api)|$(restarts worker)|$(restarts web)"; sleep 12
R2="$(restarts api)|$(restarts worker)|$(restarts web)"
BAD=$(kubectl -n $NS get pods --no-headers 2>/dev/null | grep -cE 'CrashLoopBackOff|Error|OOMKilled')
if [ "$R1" = "$R2" ] && [ "$BAD" = 0 ]; then
  ok "Sin reinicios nuevos ni pods en CrashLoopBackOff."
else
  no "Siguen los reinicios (antes $R1, ahora $R2)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Tres causas, tres arreglos: ningún pod en bucle."; exit 0; } || exit 1
