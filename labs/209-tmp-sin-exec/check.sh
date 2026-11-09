#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 209.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
mb(){ echo $(( $1 / 1048576 )); }   # bytes -> MiB

echo "== Lab 209 · /tmp, /var/tmp y /dev/shm sin ejecución — comprobación =="
for p in /tmp /var/tmp /dev/shm; do
  O=$($SUDO findmnt -no OPTIONS "$p" 2>/dev/null)
  bad=""; for f in nosuid nodev noexec; do echo ",$O," | grep -q ",$f," || bad="$bad $f"; done
  [ -z "$bad" ] && ok "$p montado con nosuid,nodev,noexec." || no "$p: faltan opciones:$bad (findmnt $p)."
  grep -E "^[^#]*[[:space:]]$p[[:space:]]" /etc/fstab | grep -q noexec && ok "$p persistente en fstab con noexec." || no "$p no está en /etc/fstab con noexec."
done
[ "$($SUDO findmnt -no FSTYPE /tmp 2>/dev/null)" = tmpfs ] && ok "/tmp es un tmpfs." || no "/tmp debería ser un tmpfs."
[ "$($SUDO stat -c %a /tmp)" = 1777 ] && ok "/tmp conserva el modo 1777 (sticky)." || no "/tmp debe tener modo 1777."
for p in /tmp /var/tmp /dev/shm; do
  cp /bin/true "$p/.tc-exec" 2>/dev/null && chmod 755 "$p/.tc-exec"
  "$p/.tc-exec" >/dev/null 2>&1 && no "Aún se ejecutan binarios en $p." || ok "Ejecutar desde $p da Permission denied."
  rm -f "$p/.tc-exec"
done
n=0; while read -r h; do for f in $H/evidencia/.[!.]* $H/evidencia/*; do [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$h" ] && { n=$((n+1)); break; }; done; done < <($SUDO cat /opt/lab/ev.sha)
[ "$n" -eq 3 ] && ok "Los 3 ficheros sospechosos están en ~/evidencia (intactos)." || no "En ~/evidencia faltan ficheros sospechosos ($n de 3): cópialos ANTES de montar el tmpfs."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Directorios temporales endurecidos y evidencia a salvo."; exit 0; } || exit 1
