#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export KUBECONFIG=$HOME/.kube/config
cd ~/gitops
git pull -q --ff-only origin main
REPO=$(kubectl -n argocd get app tienda -o jsonpath='{.spec.source.repoURL}')
mkdir -p argocd
for a in tienda pagos catalogo; do
  cat > argocd/$a.yaml <<YML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $a
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO
    targetRevision: main
    path: apps/$a
  destination:
    server: https://kubernetes.default.svc
    namespace: $a
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true]
YML
done
cat > raiz.yaml <<YML
# Única Application que se crea a mano: despliega todas las demás desde argocd/.
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: raiz
  namespace: argocd
spec:
  project: default
  source:
    repoURL: $REPO
    targetRevision: main
    path: argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated: {prune: true, selfHeal: true}
YML
git add -A
git commit -qm "argocd: App of Apps (tienda, pagos desde main, catalogo)"
git push -q origin main
kubectl apply -f raiz.yaml

for a in raiz tienda pagos catalogo; do
  for _ in $(seq 1 60); do
    kubectl -n argocd annotate app raiz argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1 || true
    [ "$(kubectl -n argocd get app $a -o jsonpath='{.status.sync.status}/{.status.health.status}' 2>/dev/null)" = Synced/Healthy ] && break
    sleep 5
  done
done
kubectl -n argocd get applications
echo "solve.sh completado."
