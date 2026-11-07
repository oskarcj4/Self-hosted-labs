#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
pide(){ kubectl -n tienda exec deploy/cliente -- wget -q -T 3 -O - "http://$1/" 2>/dev/null | head -1; }
# listos SVC: direcciones listas en sus EndpointSlices
listos(){ kubectl -n tienda get endpointslices -l kubernetes.io/service-name="$1" -o json 2>/dev/null | python3 -c '
import json,sys
d=json.load(sys.stdin); print(sum(1 for s in d["items"] for e in (s.get("endpoints") or []) if (e.get("conditions") or {}).get("ready")))'; }
replicas(){ kubectl -n tienda get deploy "$1" -o jsonpath='{.spec.replicas}' 2>/dev/null; }

echo "== Lab 192 · Services sin tráfico — comprobación =="

for s in catalogo pagos carrito usuarios; do
  R=$(pide $s); L=$(listos $s); N=$(replicas $s)
  P=$(kubectl -n tienda get svc $s -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
  if [ "$R" = "$s ok" ] && [ "$P" = 80 ] && [ -n "$N" ] && [ "$L" = "$N" ]; then
    ok "$s: responde '$R' por el puerto 80, con $L/$N réplicas detrás."
  else
    no "$s: respuesta '${R:-ninguna}', puerto ${P:-?}, réplicas listas tras el Service ${L:-0}/${N:-?}."
  fi
done

RP=$(kubectl -n tienda get deploy carrito -o jsonpath='{.spec.template.spec.containers[0].readinessProbe.httpGet.path}' 2>/dev/null)
if [ -n "$RP" ]; then
  ok "carrito conserva su readinessProbe (httpGet $RP)."
else
  no "carrito no tiene readinessProbe httpGet: hay que arreglarla, no quitarla."
fi

# Lo aplicado coincide con lo guardado en ~/manifiestos
DIF=""
for f in /home/analista/manifiestos/*.yaml; do
  kubectl diff -f "$f" >/dev/null 2>&1; [ $? -eq 1 ] && DIF="$DIF $(basename "$f")"
done
[ -z "$DIF" ] && ok "Lo que corre en el clúster coincide con ~/manifiestos." \
              || no "El clúster no coincide con ~/manifiestos (kubectl diff):$DIF."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Selector, targetPort, readiness y puerto con nombre: los cuatro clásicos."; exit 0; } || exit 1
