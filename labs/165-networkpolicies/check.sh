#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
reach(){ kubectl -n "$1" exec deploy/"$2" -- wget -q -T 3 -O /dev/null "$3" >/dev/null 2>&1; }

echo "== Lab 165 · NetworkPolicies — comprobación =="

# 1) Política de negar por defecto
if kubectl -n tienda get networkpolicy -o json 2>/dev/null | python3 -c '
import json, sys
for p in json.load(sys.stdin)["items"]:
    s = p["spec"]
    if s.get("podSelector", {}) in ({}, {"matchLabels": {}}) and "Ingress" in s.get("policyTypes", []) and not s.get("ingress"):
        sys.exit(0)
sys.exit(1)'; then
  ok "Hay una política default-deny de entrada en tienda."
else
  no "Falta la política default-deny (podSelector: {}, policyTypes: [Ingress], sin reglas)."
fi

# 2) Flujos permitidos
if reach tienda frontend http://api.tienda:8080 && reach tienda api http://db.tienda:5432; then
  ok "frontend -> api y api -> db funcionan."
else
  no "frontend -> api:8080 o api -> db:5432 están cortados (ejecuta probar-red)."
fi
if reach monitoring prometheus http://api.tienda:8080; then
  ok "monitoring -> api:8080 funciona."
else
  no "El namespace monitoring no llega a api:8080 (usa namespaceSelector)."
fi

# 3) Flujos bloqueados
B=0
reach tienda frontend http://db.tienda:5432 && B=$((B+1))
reach monitoring prometheus http://db.tienda:5432 && B=$((B+1))
reach externo atacante http://api.tienda:8080 && B=$((B+1))
reach externo atacante http://db.tienda:5432 && B=$((B+1))
reach externo atacante http://frontend.tienda:8080 && B=$((B+1))
if [ "$B" = 0 ]; then
  ok "Bloqueado: frontend->db, monitoring->db y externo->tienda."
else
  no "Quedan $B flujos que deberían estar bloqueados (ejecuta probar-red)."
fi

# 4) Las políticas están versionadas en ~/politicas
if grep -rqs 'kind: *NetworkPolicy' /home/analista/politicas/; then
  ok "Las políticas están guardadas en ~/politicas/."
else
  no "Guarda tus NetworkPolicy en ~/politicas/*.yaml."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Negar por defecto y abrir sólo lo necesario."; exit 0; } || exit 1
