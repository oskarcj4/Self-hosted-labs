#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
K="kubectl -n tienda"
T=$(mktemp -d)
listos(){ $K get deploy "$1" -o jsonpath='{.status.availableReplicas}' 2>/dev/null; }

echo "== Lab 197 · Mantenimiento de nodos — comprobación =="

# PDBs: existen y protegen al menos lo mismo que antes.
DP=$($K get pdb pagos -o jsonpath='{.status.desiredHealthy}' 2>/dev/null)
DC=$($K get pdb catalogo -o jsonpath='{.status.desiredHealthy}' 2>/dev/null)
SP=$($K get pdb pagos -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
SC=$($K get pdb catalogo -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null)
if [ "$SP" = pagos ] && [ "${DP:-0}" -ge 2 ] && [ "$SC" = catalogo ] && [ "${DC:-0}" -ge 1 ]; then
  ok "Los PDB siguen ahí: pagos exige ≥$DP disponibles y catalogo ≥$DC."
else
  no "Faltan los PDB o se han relajado (pagos desiredHealthy='$DP' ≥2, catalogo='$DC' ≥1)."
fi

OWN=$($K get pods -l app=informe -o jsonpath='{.items[*].metadata.ownerReferences[0].kind}' 2>/dev/null)
if [ -n "$OWN" ] && ! $K get pod informe >/dev/null 2>&1; then
  ok "informe lo gestiona un controlador ($OWN), no es un pod suelto."
else
  no "informe sigue siendo un pod suelto (sin controlador): drain no puede moverlo sin perderlo."
fi

# Prepara: todo vuelve a nodo2 para que el drain tenga trabajo de verdad.
kubectl uncordon nodo1 nodo2 >/dev/null 2>&1
kubectl cordon nodo1 >/dev/null 2>&1
$K rollout restart deploy/pagos deploy/catalogo >/dev/null 2>&1
$K rollout status deploy/pagos --timeout=120s >/dev/null 2>&1
$K rollout status deploy/catalogo --timeout=120s >/dev/null 2>&1
kubectl uncordon nodo1 >/dev/null 2>&1
sleep 3

# Vigía: cada segundo anota cuántos pods disponibles hay durante el drain.
( while [ ! -e $T/fin ]; do echo "$(listos pagos) $(listos catalogo)" >> $T/vigia; sleep 1; done ) &
VIG=$!
kubectl drain nodo2 --ignore-daemonsets --timeout=150s > $T/drain 2>&1; DR=$?
touch $T/fin; wait $VIG 2>/dev/null
RESTO=$(kubectl get pods -A --field-selector spec.nodeName=nodo2 -o json 2>/dev/null | python3 -c '
import json,sys
print(" ".join(p["metadata"]["namespace"]+"/"+p["metadata"]["name"] for p in json.load(sys.stdin)["items"]
  if not any(o.get("kind")=="DaemonSet" for o in p["metadata"].get("ownerReferences") or [])))')
if [ $DR -eq 0 ] && [ -z "$RESTO" ]; then
  ok "kubectl drain nodo2 termina sin --force y el nodo queda vacío."
else
  no "kubectl drain nodo2 no termina o deja pods (${RESTO:-sin restos}): $(grep -iE 'error|cannot|evict' $T/drain | tail -1)"
fi
MINP=$(awk '{print ($1==""?0:$1)}' $T/vigia | sort -n | head -1)
MINC=$(awk '{print ($2==""?0:$2)}' $T/vigia | sort -n | head -1)
if [ "${MINP:-0}" -ge 2 ] && [ "${MINC:-0}" -ge 1 ]; then
  ok "Sin cortes durante el drain: pagos nunca bajó de $MINP y catalogo de $MINC."
else
  no "Hubo corte durante el drain: mínimo pagos=${MINP:-?} (≥2), catalogo=${MINC:-?} (≥1)."
fi
kubectl uncordon nodo2 >/dev/null 2>&1

IR=$($K get pods -l app=informe -o jsonpath='{.items[*].status.phase}' 2>/dev/null)
echo "$IR" | grep -q Running && ok "informe sigue corriendo después del mantenimiento." \
                             || no "informe ya no corre después del drain."

DIF=""
for f in /home/analista/manifiestos/*.yaml; do
  kubectl diff -f "$f" >/dev/null 2>&1; [ $? -eq 1 ] && DIF="$DIF $(basename "$f")"
done
[ -z "$DIF" ] && ok "Lo que corre coincide con ~/manifiestos." \
              || no "El clúster no coincide con ~/manifiestos:$DIF (kubectl diff)."
rm -rf $T

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Nodo vaciado sin --force y sin cortes: así se hace mantenimiento."; exit 0; } || exit 1
