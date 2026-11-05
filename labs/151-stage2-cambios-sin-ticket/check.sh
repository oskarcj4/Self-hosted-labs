#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 151.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista

echo "== Lab 151 · Stage 2: cambios sin ticket — comprobación =="

# 1) etckeeper vigila /etc
if command -v etckeeper >/dev/null 2>&1 && $SUDO test -d /etc/.git; then
  ok "/etc está bajo control de versiones (etckeeper/git)."
else
  no "etckeeper no está inicializado sobre /etc."
fi

# 2) sshd_config revertido (root no se abre por SSH)
if $SUDO grep -qiE '^\s*PermitRootLogin\s+yes' /etc/ssh/sshd_config; then
  no "sshd_config sigue con 'PermitRootLogin yes' (cambio sin ticket)."
else
  ok "sshd_config revertido: root ya no se abre por SSH."
fi

# 3) Cron oculto eliminado
[ -e /etc/cron.d/stage2 ] && no "Sigue el cron sin ticket /etc/cron.d/stage2." || ok "Cron sin ticket eliminado."

# 4) Árbol de /etc limpio respecto a git
ST=$($SUDO git -C /etc status --porcelain 2>/dev/null)
if [ -z "$ST" ]; then
  ok "El árbol de /etc está limpio (coincide con la base versionada)."
else
  no "Quedan diferencias sin resolver en /etc: $(echo "$ST" | tr '\n' ' ')"
fi

# 5) Documento de cambios
C=$H/cambios.txt
if grep -qi 'sshd_config' "$C" 2>/dev/null && grep -qi 'stage2' "$C" 2>/dev/null; then
  ok "cambios.txt documenta los cambios no autorizados."
else
  no "~/cambios.txt debe listar los cambios no autorizados (sshd_config y cron.d/stage2)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Configuración de /etc auditada y devuelta a la base aprobada."; exit 0; } || exit 1
