#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
app(){ kubectl -n argocd get app tienda -o jsonpath="$1" 2>/dev/null; }

echo "== Lab 167 · Argo CD fuera de sincronía — comprobación =="

D=$(tr 'A-Z' 'a-z' < /home/analista/drift.txt 2>/dev/null)
if echo "$D" | grep -qE 'deployment/tienda' && echo "$D" | grep -qE 'configmap/tienda-web'; then
  ok "Drift identificado: deployment/tienda y configmap/tienda-web."
else
  no "~/drift.txt debe listar los recursos con drift (kind/nombre, uno por línea)."
fi

if git --git-dir=/srv/git/tienda.git show main:apps/tienda/tienda.yaml 2>/dev/null | grep -q 'Envío gratis hoy'; then
  ok "El cambio de negocio ('Envío gratis hoy') está en git."
else
  no "El mensaje 'Envío gratis hoy' no está en la rama main del repo (commit + push en ~/gitops)."
fi

kubectl -n argocd annotate app tienda argocd.argoproj.io/refresh=normal --overwrite >/dev/null 2>&1
sleep 5
S=$(app '{.status.sync.status}'); HL=$(app '{.status.health.status}')
REP=$(kubectl -n tienda get deploy tienda -o jsonpath='{.spec.replicas}' 2>/dev/null)
ENV=$(kubectl -n tienda get deploy tienda -o jsonpath='{.spec.template.spec.containers[0].env}' 2>/dev/null)
HTML=$(kubectl -n tienda get configmap tienda-web -o jsonpath='{.data.index\.html}' 2>/dev/null)
if [ "$S" = Synced ] && [ "$HL" = Healthy ] && [ "$REP" = 2 ] && ! echo "$ENV" | grep -q MODO_DEBUG \
   && echo "$HTML" | grep -q 'Envío gratis hoy'; then
  ok "App Synced/Healthy: 2 réplicas, sin MODO_DEBUG y con el mensaje nuevo."
else
  no "App: sync=$S health=$HL réplicas=$REP $(echo "$ENV" | grep -q MODO_DEBUG && echo '(MODO_DEBUG sigue)')."
fi

AU=$(app '{.spec.syncPolicy.automated}')
if echo "$AU" | grep -q '"selfHeal":true' && echo "$AU" | grep -q '"prune":true'; then
  ok "syncPolicy.automated con selfHeal y prune."
  kubectl -n tienda scale deploy tienda --replicas=6 >/dev/null 2>&1
  HEALED=0
  for _ in $(seq 1 30); do
    sleep 3
    [ "$(kubectl -n tienda get deploy tienda -o jsonpath='{.spec.replicas}')" = 2 ] && { HEALED=1; break; }
  done
  if [ "$HEALED" = 1 ]; then
    ok "Self-heal: un escalado a mano (6) volvió solo a 2."
  else
    no "Escalé a 6 a mano y Argo CD no lo revirtió en 90 s."
  fi
else
  no "Activa spec.syncPolicy.automated con selfHeal: true y prune: true."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Git vuelve a ser la verdad, y Argo CD la defiende solo."; exit 0; } || exit 1
