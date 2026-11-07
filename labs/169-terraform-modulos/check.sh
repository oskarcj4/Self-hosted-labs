#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
I=/home/analista/infra
MD=$I/modules/equipo
tfin(){ local d="$1"; shift; runuser -u analista -- env HOME=/home/analista terraform -chdir="$d" "$@"; }

echo "== Lab 169 · Terraform: módulos — comprobación =="

# 1) Estructura del módulo
if [ -f "$MD/variables.tf" ] && [ -f "$MD/outputs.tf" ] && [ -f "$MD/main.tf" ] && [ -f "$MD/versions.tf" ] \
   && grep -qE 'variable\s+"nombre"' "$MD/variables.tf" && grep -q 'validation' "$MD/variables.tf" \
   && grep -qE 'output\s+"namespace"' "$MD/outputs.tf" && grep -q 'required_providers' "$MD/versions.tf"; then
  ok "Módulo modules/equipo con variables (nombre validado), outputs y versions."
else
  no "modules/equipo necesita variables.tf (nombre + validation), main.tf, outputs.tf (namespace) y versions.tf."
fi

# 2) La validación funciona de verdad
T=$(mktemp -d); chmod 0777 "$T"
cat > "$T/main.tf" <<TF
module "x" {
  source  = "$MD"
  nombre  = "Equipo_MAL"
  cpu     = "1"
  memoria = "1Gi"
}
TF
chown -R analista "$T"
if tfin "$T" init -input=false -backend=false >/dev/null 2>&1 \
   && ! tfin "$T" validate >/dev/null 2>&1 || tfin "$T" plan -input=false 2>&1 | grep -q 'Invalid value for variable'; then
  ok "La validación de 'nombre' rechaza 'Equipo_MAL'."
else
  no "La validation de 'nombre' no rechaza 'Equipo_MAL'."
fi
rm -rf "$T"

# 3) Raíz sin recursos sueltos y con for_each
ROOT=$(cat "$I"/*.tf 2>/dev/null)
if ! echo "$ROOT" | grep -qE '^\s*resource\s+"kubernetes_' && echo "$ROOT" | grep -qE 'source\s*=\s*"\./modules/equipo"' \
   && echo "$ROOT" | grep -q 'for_each'; then
  ok "La raíz usa el módulo con for_each y sin recursos kubernetes_* sueltos."
else
  no "En la raíz: un module con source = \"./modules/equipo\" y for_each, sin resource \"kubernetes_...\"."
fi

# 4) Nada recreado
SAME=1
while read -r n uid; do
  [ "$(kubectl get ns "$n" -o jsonpath='{.metadata.uid}' 2>/dev/null)" = "$uid" ] || SAME=0
done < /opt/lab/.uids
MODST=$(tfin "$I" state list 2>/dev/null | grep -c '^module\.')
if [ "$SAME" = 1 ] && [ "$MODST" -ge 9 ]; then
  ok "Refactor sin recrear: los namespaces originales conservan su UID y viven en el módulo."
else
  no "Los namespaces originales deben seguir siendo los mismos (moved) y estar en module.* del estado."
fi

# 5) Equipo soporte
SQ=$(kubectl -n soporte get resourcequota cuota -o jsonpath='{.spec.hard.requests\.cpu} {.spec.hard.requests\.memory}' 2>/dev/null)
if [ "$(kubectl get ns soporte -o jsonpath='{.metadata.labels.equipo}' 2>/dev/null)" = soporte ] && [ "$SQ" = "1 1Gi" ] \
   && kubectl -n soporte get limitrange defaults >/dev/null 2>&1; then
  ok "Equipo soporte dado de alta (namespace, cuota 1/1Gi y LimitRange)."
else
  no "Falta el equipo soporte con cuota cpu=1 memoria=1Gi y LimitRange defaults."
fi

# 6) Output y plan limpio
OUT=$(tfin "$I" output -json namespaces 2>/dev/null)
if echo "$OUT" | grep -q soporte && echo "$OUT" | grep -q pagos; then
  ok "Output raíz 'namespaces' con los equipos."
else
  no "Falta el output raíz 'namespaces' (o no incluye todos los equipos)."
fi
tfin "$I" plan -input=false -detailed-exitcode >/tmp/plan169.log 2>&1; rc=$?
if [ $rc = 0 ]; then ok "terraform plan: sin cambios."; else no "terraform plan no está limpio (rc=$rc): tail -30 /tmp/plan169.log"; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Un módulo, cuatro equipos y nada recreado."; exit 0; } || exit 1
