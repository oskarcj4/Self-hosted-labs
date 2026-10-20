#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 34 (Día 11).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
AS_ANALISTA=""; [ "$(id -u)" -eq 0 ] && AS_ANALISTA="runuser -u analista --"
S=/opt/maint/db-maintenance.sh
C=/etc/maint/db.cred
PW='Vk7#pR2-maint-2026'

echo "== Lab 34 · Día 11 — comprobación =="

if echo "$PW" | $SUDO grep -qF -f - "$S" 2>/dev/null; then
  no "La contraseña sigue escrita dentro de $S."
else
  ok "El script ya no contiene la contraseña."
fi

if $SUDO test -f "$C" && echo "$PW" | $SUDO grep -qF -f - "$C"; then
  mode=$($SUDO stat -c '%a' "$C"); own=$($SUDO stat -c '%U' "$C")
  if [ "$own" = "root" ] && [ $((8#$mode & 077)) -eq 0 ]; then
    ok "Las credenciales viven en $C ($mode, root)."
  else
    no "$C existe pero no está cerrado: debe ser de root y sin permisos de grupo/otros (ahora $mode $own)."
  fi
else
  no "No existe $C con las credenciales."
fi

leak=""
for f in $(echo "$PW" | $SUDO grep -rlsF --exclude-dir=journal -f - /opt /etc /home /tmp /var/tmp /var/backups /srv /usr/local /var/log 2>/dev/null); do
  [ "$f" = "$C" ] && continue
  case "$f" in /opt/lab/*) continue ;; esac
  leak="$leak $f"
done
if [ -z "$leak" ]; then ok "No quedan copias de la contraseña fuera de $C (ni .orig, ni logs)."
else no "La contraseña aparece también en:$leak"; fi

if $AS_ANALISTA cat "$C" >/dev/null 2>&1; then
  no "Un usuario normal (analista) puede leer $C."
else
  ok "Un usuario normal no puede leer las credenciales."
fi

out=$($SUDO bash "$S" 2>&1)
if echo "$out" | grep -q "VACUUM OK"; then
  ok "El script de mantenimiento sigue funcionando ($out)."
else
  no "El script ya no funciona: ${out:-sin salida}"
fi

smode=$($SUDO stat -c '%a %U' "$S")
if [ "${smode#* }" = "root" ] && [ $((8#${smode% *} & 022)) -eq 0 ]; then
  ok "El script es de root y nadie más puede modificarlo."
else
  no "El script ($smode) debe ser de root y no escribible por grupo/otros."
fi

if grep -qs '/opt/maint/db-maintenance.sh' /etc/cron.d/db-maint; then
  ok "La tarea de cron sigue apuntando al script."
else
  no "La tarea de cron /etc/cron.d/db-maint ya no lanza el script."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Credenciales fuera del código. ¡Día 11 resuelto!"; exit 0; } || exit 1
