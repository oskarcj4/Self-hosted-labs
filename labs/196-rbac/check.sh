#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
DESP=system:serviceaccount:tienda:despliegue
MON=system:serviceaccount:observabilidad:monitor
APP=system:serviceaccount:tienda:default
# tabla <identidad> <esperado yes|no> <args de can-i>... -> acumula fallos en $MAL
MAL=""
espera(){ local as=$1 e=$2; shift 2
  r=$(kubectl auth can-i --as="$as" "$@" 2>/dev/null); [ "$r" = "$e" ] || MAL="$MAL|$* -> $r (esperaba $e)"; }

echo "== Lab 196 · RBAC con mínimo privilegio — comprobación =="

# 1) despliegue
MAL=""
for v in get list watch create update patch; do
  espera $DESP yes $v deployments.apps -n tienda
  espera $DESP yes $v services -n tienda
  espera $DESP yes $v configmaps -n tienda
done
for v in get list watch; do espera $DESP yes $v pods -n tienda; done
espera $DESP yes get pods --subresource=log -n tienda
[ -z "$MAL" ] && ok "despliegue puede desplegar en tienda (deployments, services, configmaps, pods y logs)." \
              || no "A despliegue le faltan permisos en tienda: $(echo "$MAL" | tr '|' '\n' | sed '/^$/d' | head -3 | paste -sd';')"

MAL=""
espera $DESP no get secrets -n tienda
espera $DESP no list secrets -n tienda
espera $DESP no get secrets -n pagos
espera $DESP no list pods -n pagos
espera $DESP no patch deployments.apps -n pagos
espera $DESP no delete namespaces
espera $DESP no create clusterrolebindings.rbac.authorization.k8s.io
espera $DESP no create rolebindings.rbac.authorization.k8s.io -n tienda
espera $DESP no create pods --subresource=exec -n tienda
espera $DESP no delete deployments.apps -n tienda
espera $DESP no '*' '*' -n tienda
[ -z "$MAL" ] && ok "despliegue no lee secrets, no sale de tienda, no escala privilegios ni hace exec." \
              || no "despliegue puede demasiado: $(echo "$MAL" | tr '|' '\n' | sed '/^$/d' | head -3 | paste -sd';')"

ADM=$(kubectl get clusterrolebindings -o json | python3 -c '
import json,sys
for b in json.load(sys.stdin)["items"]:
    if b["roleRef"]["name"] in ("cluster-admin","admin","edit"):
        for s in b.get("subjects") or []:
            if s.get("kind")=="ServiceAccount" and s.get("namespace") in ("tienda","observabilidad","pagos"):
                print(b["metadata"]["name"])')
[ -z "$ADM" ] && ok "Ninguna ServiceAccount de las apps tiene cluster-admin/admin/edit en todo el clúster." \
              || no "Siguen existiendo ClusterRoleBindings de admin para cuentas de apps: $ADM."

# 2) despliegue de verdad: rollout restart con la identidad del CI
if kubectl --as=$DESP -n tienda rollout restart deploy/tienda >/dev/null 2>&1 \
   && kubectl --as=$DESP -n tienda rollout status deploy/tienda --timeout=120s >/dev/null 2>&1; then
  ok "Un rollout restart como despliegue funciona de principio a fin."
else
  no "kubectl --as=$DESP -n tienda rollout restart deploy/tienda falla o no termina."
fi

# 3) app (default de tienda)
MAL=""
for a in "get secrets" "list secrets" "list pods" "get configmaps" "create pods" "get deployments.apps"; do
  espera $APP no $a -n tienda
done
TOK=$(kubectl -n tienda exec deploy/tienda -- ls /var/run/secrets/kubernetes.io/serviceaccount/token 2>/dev/null)
AM=$(kubectl -n tienda get deploy tienda -o jsonpath='{.spec.template.spec.automountServiceAccountToken}' 2>/dev/null)
AMS=$(kubectl -n tienda get sa default -o jsonpath='{.automountServiceAccountToken}' 2>/dev/null)
if [ -z "$MAL" ] && [ -z "$TOK" ] && { [ "$AM" = false ] || [ "$AMS" = false ]; }; then
  ok "La app no tiene permisos y su pod no monta token."
else
  [ -n "$MAL" ] && no "La cuenta default de tienda aún tiene permisos: $(echo "$MAL" | tr '|' '\n' | sed '/^$/d' | head -2 | paste -sd';')" \
                || no "El pod de la tienda sigue montando el token de la ServiceAccount (automountServiceAccountToken)."
fi

# 4) monitor
MAL=""
for v in get list watch; do
  espera $MON yes $v pods -A
  espera $MON yes $v pods -n pagos
  espera $MON yes $v nodes
done
espera $MON no get secrets -n pagos
espera $MON no list secrets -A
espera $MON no delete pods -n tienda
espera $MON no create pods --subresource=exec -n tienda
espera $MON no patch nodes
[ -z "$MAL" ] && ok "monitor lee pods de todo el clúster y nodos; ni secrets ni escritura." \
              || no "monitor: $(echo "$MAL" | tr '|' '\n' | sed '/^$/d' | head -3 | paste -sd';')"

DIF=""
for f in /home/analista/rbac/*.yaml /home/analista/manifiestos/*.yaml; do
  kubectl diff -f "$f" >/dev/null 2>&1; [ $? -eq 1 ] && DIF="$DIF $(basename "$f")"
done
[ -z "$DIF" ] && ok "Lo aplicado coincide con ~/rbac y ~/manifiestos." \
              || no "El clúster no coincide con:$DIF (kubectl diff)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Cada identidad, sólo lo que necesita."; exit 0; } || exit 1
