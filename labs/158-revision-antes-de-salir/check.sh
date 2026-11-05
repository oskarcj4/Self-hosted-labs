#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
CL=/home/analista/checklist.txt

echo "== Lab 158 · Revisión antes de salir — comprobación =="

# 1) Servicio no root
U=$($SUDO systemctl show allsafe-api -p User --value 2>/dev/null)
if [ -n "$U" ] && [ "$U" != "root" ]; then
  ok "El servicio corre como '$U' (no root)."
else
  no "allsafe-api sigue corriendo como root (añade User=appuser y reinicia)."
fi

# 2) Secreto 600
P=$($SUDO stat -c '%a' /etc/allsafe/secret.env 2>/dev/null)
[ "$P" = "600" ] && ok "El secreto tiene permisos 600." || no "/etc/allsafe/secret.env debe ser 600 (es ${P:-inexistente})."

# 3) Backups: script + timer + backup real
B_OK=1
$SUDO test -x /usr/local/bin/backup.sh || B_OK=0
$SUDO systemctl is-enabled allsafe-backup.timer >/dev/null 2>&1 || B_OK=0
[ -n "$($SUDO ls -A /var/backups/allsafe 2>/dev/null)" ] || B_OK=0
[ "$B_OK" = 1 ] && ok "Backups: script ejecutable, timer habilitado y un backup presente." \
  || no "Faltan piezas de backup (backup.sh ejecutable, timer allsafe-backup habilitado y un backup en /var/backups/allsafe)."

# 4) Runbook con secciones
R=/opt/allsafe/RUNBOOK.md
if $SUDO test -f "$R" && $SUDO grep -qi '## *Despliegue' "$R" && $SUDO grep -qi '## *Rollback' "$R" && $SUDO grep -qi '## *Contacto' "$R"; then
  ok "RUNBOOK.md con Despliegue, Rollback y Contacto."
else
  no "Falta /opt/allsafe/RUNBOOK.md con las secciones Despliegue, Rollback y Contacto."
fi

# 5) rollback.sh ejecutable
$SUDO test -x /usr/local/bin/rollback.sh && ok "rollback.sh es ejecutable." || no "Falta /usr/local/bin/rollback.sh ejecutable."

# 6) Checklist firmado y marcado
UNCHECKED=$(grep -c '^\[ \]' "$CL" 2>/dev/null); [ -z "$UNCHECKED" ] && UNCHECKED=1
if [ "$UNCHECKED" = "0" ] && grep -qiE 'Aprobado por:[[:space:]]*[^[:space:]]' "$CL" 2>/dev/null; then
  ok "checklist.txt con los 5 puntos marcados y firmado."
else
  no "Marca [x] los 5 puntos de ~/checklist.txt y pon 'Aprobado por: <nombre>'."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Go-live revisado: seguridad, backups, runbook y rollback listos."; exit 0; } || exit 1
