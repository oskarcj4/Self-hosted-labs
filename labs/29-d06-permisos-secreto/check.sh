#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 29 (Día 06).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
K=/etc/billing/secret.key

echo "== Lab 29 · Día 06 — comprobación =="

if ! $SUDO test -e "$K"; then
  no "No existe $K."
else
  mode=$($SUDO stat -c '%a' "$K"); own=$($SUDO stat -c '%U' "$K"); grp=$($SUDO stat -c '%G' "$K")
  other=$((8#$mode & 7)); gw=$(( (8#$mode >> 3) & 2 ))
  if [ "$other" -eq 0 ]; then ok "Otros usuarios no tienen ningún permiso sobre la clave ($mode)."
  else no "La clave sigue accesible para cualquier usuario (modo $mode)."; fi
  if { [ "$own" = "root" ] || [ "$own" = "billing" ]; } && { [ "$grp" = "root" ] || [ "$grp" = "billing" ]; } && [ "$gw" -eq 0 ]; then
    ok "Dueño/grupo acotados ($own:$grp) y sin escritura de grupo."
  else
    no "Dueño/grupo inadecuados ($own:$grp, modo $mode): usa root o billing, sin escritura de grupo."
  fi
  if [ "$($SUDO sha256sum "$K" | cut -d' ' -f1)" = "$($SUDO cat /root/.tclab-secret.sha)" ]; then
    ok "El contenido de la clave no cambió."
  else
    no "La clave fue modificada o regenerada: sólo había que cambiar permisos."
  fi
fi

dmode=$($SUDO stat -c '%a' /etc/billing)
if [ $((8#$dmode & 2)) -eq 0 ]; then ok "/etc/billing ya no es escribible por todos ($dmode)."
else no "/etc/billing sigue siendo world-writable ($dmode): cualquiera podría sustituir la clave."; fi

AS_ANALISTA=""; [ "$(id -u)" -eq 0 ] && AS_ANALISTA="runuser -u analista --"
if $AS_ANALISTA cat "$K" >/dev/null 2>&1; then
  no "El usuario analista todavía puede leer la clave."
else
  ok "Un usuario cualquiera (analista) ya no puede leer la clave."
fi

if systemctl is-active --quiet billing-api && curl -s --max-time 3 http://127.0.0.1:8200/health | grep -q "secret loaded"; then
  ok "billing-api sigue activo y leyendo su secreto."
else
  no "billing-api no puede leer la clave (curl 127.0.0.1:8200/health)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Secreto protegido y servicio operativo. ¡Día 06 resuelto!"; exit 0; } || exit 1
