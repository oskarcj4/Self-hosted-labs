#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
NS=web

echo "== Lab 166 · Escalado con HPA — comprobación =="

C=$(grep -iE '^\s*causa\s*=' /home/analista/hpa.txt 2>/dev/null | cut -d= -f2- | tr 'A-Z' 'a-z')
if echo "$C" | grep -qE 'request'; then
  ok "Causa identificada: faltaban requests de CPU."
else
  no "~/hpa.txt: causa=<...> (¿qué necesita el HPA para calcular el % de CPU?)."
fi

RC=$(kubectl -n $NS get deploy web -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
LM=$(kubectl -n $NS get deploy web -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null)
if [ -n "$RC" ] && [ -n "$LM" ]; then
  ok "web declara requests.cpu=$RC y limits.memory=$LM."
else
  no "web debe declarar requests.cpu y limits.memory (ahora cpu='$RC', mem='$LM')."
fi

SW=$(kubectl -n $NS get hpa web -o jsonpath='{.spec.behavior.scaleDown.stabilizationWindowSeconds}' 2>/dev/null)
MAX=$(kubectl -n $NS get hpa web -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)
if [ -n "$SW" ] && [ "$SW" -ge 60 ] && [ "${MAX:-0}" -ge 3 ]; then
  ok "HPA con ventana de estabilización de bajada de ${SW}s (máx. $MAX réplicas)."
else
  no "HPA: behavior.scaleDown.stabilizationWindowSeconds >= 60 (ahora '${SW:-sin definir}') y maxReplicas >= 3."
fi

# Prueba con carga real
if [ -n "$RC" ]; then
  echo "  ... lanzando carga (hasta 3 min) ..."
  kubectl -n $NS scale deploy carga --replicas=4 >/dev/null
  UP=0
  for _ in $(seq 1 36); do
    R=$(kubectl -n $NS get hpa web -o jsonpath='{.status.desiredReplicas}' 2>/dev/null)
    [ "${R:-0}" -ge 2 ] && { UP=1; break; }
    sleep 5
  done
  kubectl -n $NS scale deploy carga --replicas=0 >/dev/null
  if [ "$UP" = 1 ]; then
    ok "Con carga, el HPA pidió $R réplicas."
  else
    no "Con carga, el HPA no subió de 1 réplica (mira: kubectl -n web describe hpa web)."
  fi
else
  no "Sin requests de CPU no se puede probar el escalado."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 El HPA ya ve la CPU y escala con la carga."; exit 0; } || exit 1
