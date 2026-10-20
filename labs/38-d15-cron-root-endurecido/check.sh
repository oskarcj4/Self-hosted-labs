#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 38 (Día 15).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
CRON=/etc/cron.d/cache-cleanup

# ¿Puede alguien que no sea root modificar esta ruta (fichero o cualquier carpeta padre)?
unsafe_path(){
  local p="$1"
  while :; do
    [ -e "$p" ] || { echo "$p (no existe)"; return 0; }
    if [ "$(stat -c %U "$p")" != "root" ] || [ $((8#$(stat -c %a "$p") & 022)) -ne 0 ]; then
      [ -d "$p" ] && [ -k "$p" ] && [ "$p" != "$1" ] || { echo "$p ($(stat -c '%U %a' "$p"))"; return 0; }
    fi
    [ "$p" = "/" ] && return 1
    p=$(dirname "$p")
  done
}

echo "== Lab 38 · Día 15 — comprobación =="

line=$(grep -vE '^\s*(#|$|[A-Za-z_]+=)' "$CRON" 2>/dev/null | grep cleanup | head -1)
cmd=$(echo "$line" | awk '{print $7}')
user=$(echo "$line" | awk '{print $6}')
if [ -n "$cmd" ]; then
  ok "La tarea sigue en $CRON (usuario: $user, script: $cmd)."
else
  no "No encuentro la tarea de limpieza en $CRON."
fi

if [ -n "$cmd" ]; then
  case "$cmd" in
    /tmp/*|/var/tmp/*|/dev/shm/*|/home/*|/run/user/*)
      no "El script sigue en una carpeta temporal o de usuario ($cmd)." ;;
    /*) ok "El script está en una ubicación de sistema ($cmd)." ;;
    *)  no "La tarea no usa una ruta absoluta ($cmd)." ;;
  esac
  bad=$(unsafe_path "$cmd")
  if [ -z "$bad" ]; then ok "El script y todas sus carpetas padre son de root y nadie más puede escribirlas."
  else no "Alguien que no es root puede modificar el script o su ruta: $bad"; fi
fi

if [ "$(stat -c %U "$CRON")" = "root" ] && [ $((8#$(stat -c %a "$CRON") & 022)) -eq 0 ]; then
  ok "$CRON es de root y no escribible por otros."
else
  no "$CRON tiene permisos inseguros ($(stat -c '%U %a' "$CRON"))."
fi

if grep -rqs '/var/tmp/jobs' /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /var/spool/cron 2>/dev/null; then
  no "Aún queda alguna tarea de cron que apunta a /var/tmp/jobs."
else
  ok "Ninguna tarea de cron apunta ya a /var/tmp/jobs."
fi

if [ -n "$cmd" ] && [ -x "$cmd" ]; then
  $SUDO sh -c 'echo t > /var/cache/app/tclab-check.tmp'
  out=$($SUDO "$cmd" 2>&1)
  if ! $SUDO test -e /var/cache/app/tclab-check.tmp && $SUDO test -e /var/cache/app/index.dat; then
    ok "El script sigue limpiando los temporales (y respeta el resto): $out"
  else
    no "El script no limpia bien /var/cache/app: ${out:-sin salida}"
  fi
else
  no "El script de la tarea no existe o no es ejecutable."
fi

if systemctl is-active --quiet cron; then ok "cron está activo."; else no "cron no está activo."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Tarea de root blindada. ¡Día 15 resuelto!"; exit 0; } || exit 1
