#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=$HOME/.kube/config
printf 'deployment/tienda\nconfigmap/tienda-web\n' > ~/drift.txt
cd ~/gitops
python3 - <<'PY'
p = "apps/tienda/tienda.yaml"
s = open(p, encoding="utf-8").read()
s = s.replace("    <h1>Bienvenido a la tienda</h1>\n",
              "    <h1>Bienvenido a la tienda</h1>\n    <p>Envío gratis hoy</p>\n", 1)
open(p, "w", encoding="utf-8").write(s)
PY
git commit -qam "tienda: mensaje 'Envío gratis hoy' (pedido de negocio, aplicado en la guardia)"
git push -q origin main
kubectl -n argocd patch app tienda --type merge -p \
  '{"spec":{"syncPolicy":{"automated":{"selfHeal":true,"prune":true},"syncOptions":["CreateNamespace=true"]}}}'
kubectl -n argocd annotate app tienda argocd.argoproj.io/refresh=hard --overwrite
for _ in $(seq 1 40); do
  s=$(kubectl -n argocd get app tienda -o jsonpath='{.status.sync.status}/{.status.health.status}')
  echo "  $s"; [ "$s" = Synced/Healthy ] && break; sleep 5
done
echo "solve.sh completado."
