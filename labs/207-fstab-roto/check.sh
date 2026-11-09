#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 207.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 207 · /etc/fstab roto antes de un reinicio — comprobación =="
VER=$($SUDO findmnt --verify --tab-file /etc/fstab 2>&1)
BADV=$(echo "$VER" | awk '/^\//{m=$1} /\[E\]/ && m!="/backup"{print m}' | sort -u | tr '
' ' ')
echo "$VER" | grep -q ' 0 parse errors\|^0 parse errors' && [ -z "$BADV" ] && ok "findmnt --verify: sin errores (salvo el /backup ausente, esperado)." || no "findmnt --verify aún muestra errores en: ${BADV:-formato}."
$SUDO mount -a >/dev/null 2>&1 && ok "mount -a termina sin error." || no "mount -a devuelve error."
[ "$($SUDO findmnt -no FSTYPE /datos 2>/dev/null)" = ext4 ] && $SUDO test -f /datos/ok.txt && ok "/datos montado (ext4) con su contenido." || no "/datos no está montado correctamente."
[ "$($SUDO findmnt -no FSTYPE /var/log/app 2>/dev/null)" = ext4 ] && $SUDO test -f /var/log/app/ok.txt && ok "/var/log/app montado (ext4) con su contenido." || no "/var/log/app no está montado correctamente."
grep -E '^[^#]*[[:space:]]/backup[[:space:]]' /etc/fstab | grep -q 'nofail' && ok "/backup tiene nofail." || no "La línea de /backup debe llevar nofail (o el arranque se corta si el volumen no está)."
grep -vE '^[[:space:]]*#' /etc/fstab | grep -q '/dev/loop' && no "fstab usa /dev/loopN (inestable): usa LABEL= o UUID=." || ok "fstab no depende de nombres /dev/loopN."
grep -vE '^[[:space:]]*#' /etc/fstab | grep -q 'ext44' && no "Queda un tipo de sistema de ficheros erróneo (ext44)." || ok "Tipos de sistema de ficheros válidos."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 fstab limpio: monta todo y un volumen ausente ya no bloquea el arranque."; exit 0; } || exit 1
