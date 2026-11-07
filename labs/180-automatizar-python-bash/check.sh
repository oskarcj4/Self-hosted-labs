#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
S=/home/analista/scripts
B=$S/rotar-backups.sh
P=$S/informe_errores.py

echo "== Lab 180 · Automatizar con Bash y Python — comprobación =="

if [ -f "$B" ] && SC=$(runuser -u analista -- shellcheck "$B" 2>&1); then
  ok "shellcheck: rotar-backups.sh sin avisos."
else
  no "shellcheck rotar-backups.sh: $(echo "$SC" | grep -m1 -oE 'SC[0-9]+.*' || echo 'falta el script')"
fi

OUT=$(timeout 120 python3 /opt/lab/tests/casos.py bash "$B" 2>&1); rc=$?
echo "$OUT" | sed 's/^/      /'
[ $rc = 0 ] && ok "rotar-backups.sh supera los casos ocultos." || no "rotar-backups.sh falla casos ocultos (arriba)."

OUT=$(timeout 120 python3 /opt/lab/tests/casos.py python "$P" 2>&1); rc=$?
echo "$OUT" | sed 's/^/      /'
[ $rc = 0 ] && ok "informe_errores.py supera los casos ocultos." || no "informe_errores.py falla casos ocultos (arriba)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Scripts que se pueden dejar en el cron sin miedo."; exit 0; } || exit 1
