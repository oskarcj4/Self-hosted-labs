#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
I=/home/analista/infra
tf(){ runuser -u analista -- env HOME=/home/analista terraform -chdir="$I" "$@"; }

echo "== Lab 168 · Terraform: lock y drift — comprobación =="

WANT=$(cat /opt/lab/.lock_id 2>/dev/null)
GOT=$(grep -iE '^\s*lock_id\s*=' /home/analista/incidente.txt 2>/dev/null | cut -d= -f2- | tr -d ' ')
if [ -n "$WANT" ] && [ "$GOT" = "$WANT" ] && [ ! -e /var/lib/tfstate/tienda.lock ]; then
  ok "Bloqueo huérfano identificado ($WANT) y liberado."
elif [ -e /var/lib/tfstate/tienda.lock ]; then
  no "El estado sigue bloqueado (terraform force-unlock <ID>)."
else
  no "~/incidente.txt: lock_id=<ID del bloqueo que había> ."
fi

REP=$(kubectl -n tienda get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null)
HTML=$(kubectl -n tienda get configmap web -o jsonpath='{.data.index\.html}' 2>/dev/null)
if [ "$REP" = 2 ] && [ "$HTML" = "<h1>Tienda</h1>" ]; then
  ok "Drift revertido: 2 réplicas y ConfigMap como en el código."
else
  no "Drift sin revertir: réplicas=$REP, index.html='$HTML'."
fi

QUID=$(kubectl -n tienda get resourcequota cuota-tienda -o jsonpath='{.metadata.uid}' 2>/dev/null)
if tf state list 2>/dev/null | grep -q '^kubernetes_resource_quota_v1\.'; then
  HARD=$(kubectl -n tienda get resourcequota cuota-tienda -o jsonpath='{.spec.hard.pods} {.spec.hard.requests\.cpu} {.spec.hard.requests\.memory}' 2>/dev/null)
  if [ "$HARD" = "20 2 2Gi" ]; then
    ok "cuota-tienda está en el estado de Terraform con sus valores (pods=20, cpu=2, mem=2Gi)."
  else
    no "cuota-tienda importada, pero sus valores cambiaron ('$HARD'): el código debe reflejar lo que había."
  fi
else
  no "cuota-tienda no está en el estado (bloque kubernetes_resource_quota_v1 + terraform import)."
fi
[ -n "$QUID" ] || no "La ResourceQuota cuota-tienda ya no existe."

tf plan -input=false -detailed-exitcode -lock-timeout=10s >/tmp/plan168.log 2>&1; rc=$?
if [ $rc = 0 ]; then
  ok "terraform plan: sin cambios pendientes."
else
  no "terraform plan no está limpio (rc=$rc). Mira: tail -30 /tmp/plan168.log"
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Estado desbloqueado, sin drift y todo bajo código."; exit 0; } || exit 1
