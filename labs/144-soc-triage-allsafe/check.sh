#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 144.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista

echo "== Lab 144 · Triage en el SOC de Allsafe — comprobación =="

grep -qE '^ip_atacante=203\.0\.113\.7\s*$' $H/triage.txt 2>/dev/null \
  && ok "triage: atacante correcto (203.0.113.7)." || no "triage.txt: ip_atacante= no es el origen de los incidentes reales."

ESPERADO=$($SUDO cat /etc/soc/.ground_truth 2>/dev/null | tr ',' '\n' | sort -u)
DADO=$(grep -E '^alertas_reales=' $H/triage.txt 2>/dev/null | head -1 | cut -d= -f2- | tr ', ' '\n' | grep -E '^[0-9]+$' | sort -u)
if [ -n "$DADO" ] && [ "$DADO" = "$ESPERADO" ]; then
  ok "triage: los 3 incidentes reales identificados (sin falsos positivos)."
else
  no "triage.txt: alertas_reales= no coincide con los 3 incidentes reales (nivel>=10)."
fi

grep -qE '^regla_ruidosa=healthcheck_http\s*$' $H/triage.txt 2>/dev/null \
  && ok "triage: regla ruidosa identificada (healthcheck_http)." || no "triage.txt: regla_ruidosa= no es la regla de ruido (health checks internos)."

if [ -f /etc/soc/supresiones.txt ] && grep -qxE '\s*healthcheck_http\s*' /etc/soc/supresiones.txt; then
  ok "healthcheck_http silenciada en /etc/soc/supresiones.txt."
else
  no "/etc/soc/supresiones.txt debe contener healthcheck_http (una regla por línea)."
fi

# No haber "silenciado" un incidente real por error.
for r in ssh_bruteforce_success web_shell_upload privesc_sudo vuln_scan; do
  grep -qxE "\s*$r\s*" /etc/soc/supresiones.txt 2>/dev/null && no "No silencies '$r' (es un incidente real o un escaneo a vigilar)." && break
done

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Ruido bajo control y los 3 incidentes reales a la vista."; exit 0; } || exit 1
