#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 37 (Día 14). Ejecuta el script como root con un PATH
# envenenado: si llama a algún impostor, se nota.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
S=/usr/local/sbin/backup-config.sh
DEST=/var/backups/config
CRON=/etc/cron.d/backup-config

echo "== Lab 37 · Día 14 — comprobación =="

EVIL=$(mktemp -d)
MARK="$EVIL/PWNED"
for c in tar gzip date mkdir sha256sum cat cp mv rm ls find sed awk grep env sh bash dirname basename; do
  printf '#!/bin/sh\necho "%s" >> %s\nexec /usr/bin/%s "$@"\n' "$c" "$MARK" "$c" > "$EVIL/$c"
  chmod 0755 "$EVIL/$c"
done
chmod 0777 "$EVIL"
before=$($SUDO find "$DEST" -name 'config-*.tar.gz' 2>/dev/null | wc -l)
out=$($SUDO env -i HOME=/root PATH="$EVIL:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" "$S" 2>&1)
rc=$?
if [ -e "$MARK" ]; then
  no "Con un PATH envenenado, el script ejecutó impostores como root: $(sort -u "$MARK" | tr '\n' ' ')"
else
  ok "El script ignora el PATH heredado: no ejecuta comandos impostores."
fi
after=$($SUDO find "$DEST" -name 'config-*.tar.gz' 2>/dev/null | wc -l)
newest=$($SUDO ls -t "$DEST"/config-*.tar.gz 2>/dev/null | head -1)
if [ "$rc" -eq 0 ] && [ "$after" -gt "$before" ] && $SUDO tar -tzf "$newest" 2>/dev/null | grep -q 'app/app.conf'; then
  ok "La copia sigue funcionando ($(basename "$newest") contiene app/app.conf)."
else
  no "La copia ya no se genera bien (rc=$rc): $(echo "$out" | tail -1)"
fi
rm -rf "$EVIL"

own=$(stat -c '%U' "$S"); mode=$(stat -c '%a' "$S")
if [ "$own" = "root" ] && [ $((8#$mode & 022)) -eq 0 ]; then ok "El script es de root y no lo puede modificar nadie más."
else no "El script ($own $mode) debería ser de root y sin escritura de grupo/otros."; fi

cp=$(grep -E '^\s*PATH=' "$CRON" 2>/dev/null | tail -1 | cut -d= -f2-)
bad=""
for d in $(echo "${cp:-/usr/bin:/bin}" | tr ':' ' '); do
  [ -d "$d" ] || continue
  if [ -n "$(find -L "$d" -maxdepth 0 -perm -0002 2>/dev/null)" ] || [ "$(stat -L -c %U "$d")" != "root" ]; then bad="$bad $d"; fi
done
if [ -z "$bad" ]; then ok "Todas las carpetas del PATH de cron son de root y no escribibles por otros."
else no "El PATH de cron incluye carpetas inseguras:$bad"; fi

if [ -n "$(find /opt/tools/bin -perm -0002 2>/dev/null)" ]; then
  no "/opt/tools/bin (o algo dentro) sigue siendo escribible por todos."
else
  ok "/opt/tools/bin ya no es escribible por todos."
fi

if grep -qE '^[^#].*root .*backup-config' "$CRON" 2>/dev/null; then ok "La tarea de cron sigue programada."
else no "La tarea de cron $CRON ya no lanza la copia."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Script inmune al PATH. ¡Día 14 resuelto!"; exit 0; } || exit 1
