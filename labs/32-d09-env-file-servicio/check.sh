#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 32 (Día 09).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
AS_ANALISTA=""; [ "$(id -u)" -eq 0 ] && AS_ANALISTA="runuser -u analista --"
E=/etc/notifier/notifier.env
PW="mXq-7Rt-notifier-2026"

echo "== Lab 32 · Día 09 — comprobación =="

if $SUDO test -f "$E"; then
  mode=$($SUDO stat -c '%a' "$E"); own=$($SUDO stat -c '%U' "$E"); grp=$($SUDO stat -c '%G' "$E")
  if [ $((8#$mode & 7)) -eq 0 ] && [ $(( (8#$mode >> 3) & 2 )) -eq 0 ] && [ "$own" = "root" ] \
     && { [ "$grp" = "root" ] || [ "$grp" = "notifier" ]; }; then
    ok "notifier.env protegido ($mode $own:$grp)."
  else
    no "notifier.env sigue demasiado abierto ($mode $own:$grp). Pista: systemd lo lee como root."
  fi
else
  no "No existe $E (el servicio lo necesita)."
fi

leak=""
for f in $($SUDO find /etc/notifier /opt/notifier /tmp /var/tmp /home -type f 2>/dev/null); do
  if echo "$PW" | $SUDO grep -qF -f - "$f" 2>/dev/null && $AS_ANALISTA test -r "$f" 2>/dev/null; then
    leak="$leak $f"
  fi
done
if [ -z "$leak" ]; then ok "Ningún fichero legible por usuarios normales contiene los secretos (ni copias .bak)."
else no "Siguen legibles por cualquiera:$leak"; fi

if systemctl show notifier -p EnvironmentFiles --value | grep -q "$E"; then
  ok "La unidad sigue cargando los secretos desde $E."
else
  no "La unidad ya no usa EnvironmentFile=$E."
fi

if systemctl cat notifier 2>/dev/null | grep -qF "$PW"; then
  no "El secreto está escrito en la unidad (las unidades son legibles por todos: systemctl cat)."
else
  ok "Los secretos no están incrustados en ficheros de unidad."
fi

if systemctl is-active --quiet notifier && curl -s --max-time 3 http://127.0.0.1:8500/ | grep -q "smtp configured, webhook configured"; then
  ok "notifier activo y con sus secretos cargados."
else
  no "notifier no está activo o no tiene sus secretos (curl 127.0.0.1:8500)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 EnvironmentFile protegido. ¡Día 09 resuelto!"; exit 0; } || exit 1
