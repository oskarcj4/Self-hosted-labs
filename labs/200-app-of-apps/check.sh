#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
A="kubectl -n argocd"
ga(){ $A get app "$1" -o jsonpath="{$2}" 2>/dev/null; }
refresca(){ $A annotate app raiz argocd.argoproj.io/refresh=hard --overwrite >/dev/null 2>&1; }

echo "== Lab 200 · App of Apps — comprobación =="

# 1) Raíz
RP=$(ga raiz .spec.source.path); RR=$(ga raiz .spec.source.repoURL)
RA=$(ga raiz .spec.syncPolicy.automated); RS=$(ga raiz .status.sync.status)
if [ -n "$RP" ] && echo "$RR" | grep -q plataforma.git && echo "$RA" | grep -q '"prune":true' \
   && echo "$RA" | grep -q '"selfHeal":true' && [ "$RS" = Synced ]; then
  ok "Application raiz despliega '$RP' del repo con sync automático (prune+selfHeal) y está Synced."
else
  no "Application raiz: path='$RP' repo='$RR' automated='$RA' sync='$RS'."
fi
if [ -f /home/analista/gitops/raiz.yaml ] && grep -q 'name: *raiz' /home/analista/gitops/raiz.yaml; then
  ok "La raíz también está guardada en ~/gitops/raiz.yaml."
else
  no "Falta ~/gitops/raiz.yaml con la Application raiz."
fi

# 2) Hijas: gestionadas por la raíz, desde main, automáticas y sanas
MAL=""
for a in tienda pagos catalogo; do
  inst=$($A get app $a -o jsonpath='{.metadata.labels.app\.kubernetes\.io/instance}{.metadata.annotations.argocd\.argoproj\.io/tracking-id}' 2>/dev/null)
  rev=$(ga $a .spec.source.targetRevision); au=$(ga $a .spec.syncPolicy.automated)
  st="$(ga $a .status.sync.status)/$(ga $a .status.health.status)"
  echo "$inst" | grep -q '^raiz' || MAL="$MAL $a:no-la-gestiona-raiz"
  case "$rev" in main|HEAD|"") ;; *) MAL="$MAL $a:rama-$rev";; esac
  echo "$au" | grep -q '"selfHeal":true' && echo "$au" | grep -q '"prune":true' || MAL="$MAL $a:sin-automated"
  [ "$st" = Synced/Healthy ] || MAL="$MAL $a:$st"
done
[ -z "$MAL" ] && ok "tienda, pagos y catalogo: declaradas en git vía raiz, desde main, automáticas, Synced/Healthy." \
              || no "Applications hijas:$MAL."

R=$(kubectl -n pagos get deploy pagos -o jsonpath='{.spec.replicas}' 2>/dev/null)
IP=$(kubectl -n pagos get svc pagos -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
V=$(curl -s --max-time 3 "http://$IP/" 2>/dev/null)
C=$(kubectl -n catalogo get deploy catalogo -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
[ "$V" = "pagos v2" ] && [ "$R" = 2 ] && [ "$C" = 2 ] \
  && ok "pagos sirve v2 con 2 réplicas y catalogo está desplegado." \
  || no "pagos sirve '${V:-nada}' con ${R:-?} réplicas (esperaba 'pagos v2' y 2); catalogo listos=${C:-0}."

# 3) Alta y baja por commit
T=$(mktemp -d); chown analista:analista $T
G(){ runuser -u analista -- git -C $T/w "$@"; }
DIR=$(ga raiz .spec.source.path)
if [ -n "$DIR" ] && runuser -u analista -- git clone -q /srv/git/plataforma.git $T/w 2>/dev/null && [ -d "$T/w/$DIR" ]; then
  G config user.name check; G config user.email check@lab
  REPO=$(ga tienda .spec.source.repoURL)
  cat > $T/w/$DIR/zz-prueba-check.yaml <<YML
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: prueba-check, namespace: argocd}
spec:
  project: default
  source: {repoURL: $REPO, targetRevision: main, path: apps/tienda}
  destination: {server: https://kubernetes.default.svc, namespace: prueba-check}
  syncPolicy:
    automated: {prune: true, selfHeal: true}
    syncOptions: [CreateNamespace=true]
YML
  chown -R analista:analista $T
  G add -A; G commit -qm "check: alta de prueba"; G push -q origin HEAD:main
  ALTA=0
  for _ in $(seq 1 40); do
    refresca
    [ "$(ga prueba-check .status.sync.status)" = Synced ] && { ALTA=1; break; }
    sleep 5
  done
  G rm -q $DIR/zz-prueba-check.yaml; G commit -qm "check: baja de prueba"; G push -q origin HEAD:main
  BAJA=0
  for _ in $(seq 1 40); do
    refresca
    $A get app prueba-check >/dev/null 2>&1 || { BAJA=1; break; }
    sleep 5
  done
  kubectl delete namespace prueba-check --wait=false >/dev/null 2>&1
  [ $ALTA = 1 ] && [ $BAJA = 1 ] \
    && ok "Un commit en $DIR/ da de alta una app, y quitarlo la da de baja (prune)." \
    || no "Alta/baja por commit: alta=$([ $ALTA = 1 ] && echo sí || echo no), baja=$([ $BAJA = 1 ] && echo sí || echo no)."
else
  no "No se puede probar el alta por commit: ¿existe '$DIR' en main del repo?"
fi
rm -rf $T

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Todo Argo CD sale de git: una sola Application creada a mano."; exit 0; } || exit 1
