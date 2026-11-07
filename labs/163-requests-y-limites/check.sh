#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
NS=catalogo
F=/home/analista/qos.txt
mcpu(){ python3 -c '
import sys
v = sys.argv[1].strip()
print(int(v[:-1]) if v.endswith("m") else int(float(v or 0) * 1000))' "$1" 2>/dev/null || echo 0; }
qos(){ kubectl -n $NS get pods -l app="$1" --field-selector=status.phase=Running \
        -o jsonpath='{.items[0].status.qosClass}' 2>/dev/null; }
res(){ kubectl -n $NS get deploy "$1" -o jsonpath="{.spec.template.spec.containers[0].resources.$2}" 2>/dev/null; }

echo "== Lab 163 · Requests y límites — comprobación =="

g(){ grep -iE "^\s*$1\s*=" "$F" 2>/dev/null | head -1 | cut -d= -f2- | tr 'A-Z' 'a-z' | tr -d ' '; }
if [ "$(g api)" = besteffort ] && [ "$(g calc)" = guaranteed ] && [ "$(g scraper)" = besteffort ] \
   && g estrangulado | grep -q calc; then
  ok "Análisis QoS inicial correcto en ~/qos.txt."
else
  no "~/qos.txt: clase QoS ORIGINAL de api, calc y scraper, y estrangulado=<pod>."
fi

if [ "$(qos api)" = Guaranteed ] && [ "$(kubectl -n $NS get deploy api -o jsonpath='{.status.readyReplicas}')" = 1 ]; then
  ok "api es Guaranteed y está Ready."
else
  no "api debe ser Guaranteed (requests = limits de cpu y memoria). Ahora: $(qos api)."
fi

CL=$(res calc limits.cpu); CR=$(res calc requests.cpu)
if { [ -z "$CL" ] || [ "$(mcpu "$CL")" -ge 500 ]; } && [ -n "$CR" ] && [ "$(mcpu "$CR")" -ge 100 ]; then
  ok "calc: requests.cpu=$CR, limits.cpu=${CL:-sin límite} (sin estrangular)."
else
  no "calc: límite de CPU >= 500m (o ninguno) y request >= 100m. Ahora: req='$CR' lim='$CL'."
fi

LR=$(kubectl -n $NS get limitrange defaults -o json 2>/dev/null)
if [ -n "$LR" ] && echo "$LR" | python3 -c '
import json, sys
lr = json.load(sys.stdin)
c = [l for l in lr["spec"]["limits"] if l.get("type") == "Container"]
ok = c and all(k in c[0].get("default", {}) and k in c[0].get("defaultRequest", {}) for k in ("cpu", "memory"))
sys.exit(0 if ok else 1)'; then
  # Prueba real: un pod sin resources debe recibir los valores por defecto.
  P=$(kubectl -n $NS run qos-prueba --image=busybox:1.36 --restart=Never --dry-run=server -o json -- true 2>/dev/null)
  if echo "$P" | grep -q '"requests"'; then
    ok "LimitRange 'defaults' aplica requests y limits a los pods nuevos."
  else
    no "La LimitRange existe pero un pod nuevo no recibe valores por defecto."
  fi
else
  no "Crea la LimitRange 'defaults' (type: Container) con default y defaultRequest de cpu y memory."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Cada pod en su clase QoS y nadie estrangulado sin motivo."; exit 0; } || exit 1
