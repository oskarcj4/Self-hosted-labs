#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
NS=erp
F=/home/analista/pending.txt
avail(){ [ "$(kubectl -n $NS get deploy "$1" -o jsonpath='{.status.availableReplicas}' 2>/dev/null)" = "1" ]; }
# CPU de Kubernetes (500m, 2, 0.5) -> milinúcleos.
mcpu(){ python3 -c '
import sys
v = sys.argv[1].strip()
print(int(v[:-1]) if v.endswith("m") else int(float(v or 0) * 1000))' "$1" 2>/dev/null || echo 999999; }

echo "== Lab 162 · Pods en Pending — comprobación =="

g(){ grep -iE "^\s*$1\s*=" "$F" 2>/dev/null | head -1 | cut -d= -f2- | tr 'A-Z' 'a-z'; }
if g nodo | grep -q taint && g reportes | grep -qE 'cpu|request' \
   && g cache | grep -qE 'selector|label|etiqueta|afinidad|affinity' && g db | grep -qE 'storage|pvc|volum'; then
  ok "Diagnóstico correcto en ~/pending.txt."
else
  no "~/pending.txt: nodo=taint, reportes=cpu, cache=nodeselector, db=storageclass."
fi

if kubectl get node nodo1 -o jsonpath='{.spec.taints[*].key}' 2>/dev/null | grep -qw mantenimiento; then
  no "El nodo sigue con el taint 'mantenimiento'."
else
  ok "Taint de mantenimiento retirado del nodo."
fi

CPU=$(kubectl -n $NS get deploy reportes -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
if [ -n "$CPU" ] && [ "$(mcpu "$CPU")" -le 1000 ] && avail reportes; then
  ok "reportes: requests.cpu=$CPU y disponible."
else
  no "reportes: requests.cpu <= 1 núcleo (y que esté disponible). Ahora: '${CPU:-sin request}'."
fi

if [ "$(kubectl get node nodo1 -o jsonpath='{.metadata.labels.disktype}' 2>/dev/null)" = ssd ] && avail cache; then
  ok "cache: nodo1 etiquetado disktype=ssd y cache disponible."
else
  no "cache: etiqueta el nodo con disktype=ssd (sin quitar el nodeSelector)."
fi

SC=$(kubectl -n $NS get pvc datos-db -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
PH=$(kubectl -n $NS get pvc datos-db -o jsonpath='{.status.phase}' 2>/dev/null)
CLAIM=$(kubectl -n $NS get deploy db -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null)
if [ "$SC" = local-path ] && [ "$PH" = Bound ] && [ "$CLAIM" = datos-db ] && avail db; then
  ok "db: PVC datos-db en local-path, Bound, y db disponible."
else
  no "db: PVC datos-db con storageClassName local-path, Bound, montado por db. Ahora: sc='$SC' fase='$PH'."
fi

PEND=$(kubectl -n $NS get pods --no-headers 2>/dev/null | grep -c Pending)
if [ "$PEND" = 0 ]; then
  ok "Ningún pod en Pending en erp."
else
  no "Quedan $PEND pods en Pending."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 El scheduler ya encuentra sitio para todos."; exit 0; } || exit 1
