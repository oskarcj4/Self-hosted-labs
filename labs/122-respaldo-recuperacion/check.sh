#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 122.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 122 · Respaldo y recuperación — comprobación =="
N=$($SUDO cat /opt/lab/.ref-sums | wc -l)
grep -qE "^alterados=$N\$" /home/analista/incidente.txt 2>/dev/null && ok "Recuento de ficheros alterados correcto ($N)." \
  || no "~/incidente.txt: falta 'alterados=<N>' con el número real de ficheros cifrados."

if systemctl is-active -q datos-indexer 2>/dev/null || pgrep -f datos-indexer >/dev/null; then
  no "El proceso que cifra sigue vivo (si restauras con él activo, vuelve a cifrar)."
else
  ok "El proceso que cifraba está detenido."
fi
systemctl is-enabled -q datos-indexer 2>/dev/null && no "datos-indexer.service sigue habilitado al arranque." || ok "Su unidad ya no arranca sola."

sleep 1
if ( cd /srv/datos && $SUDO sha256sum -c --quiet /opt/lab/.ref-sums >/dev/null 2>&1 ); then
  ok "sha256sum -c: los $N ficheros restaurados son íntegros."
else
  no "sha256sum -c falla: faltan ficheros o no coinciden con el respaldo."
fi
L=$(find /srv/datos -name '*.lock' -o -name 'LEEME-RESCATE.txt' | wc -l)
[ "$L" -eq 0 ] && ok "Sin restos cifrados ni nota de rescate en /srv/datos." || no "Quedan $L ficheros .lock / nota de rescate en /srv/datos."
[ "$($SUDO stat -c %U /srv/datos/clientes/cliente-001.csv 2>/dev/null)" = datos ] && ok "Propietario original conservado (rsync -a)." || no "Los ficheros restaurados deben seguir siendo de 'datos'."
if mount | grep -q respaldo-offline || findmnt -rn -S /dev/loop* 2>/dev/null | grep -q respaldo; then
  no "El respaldo sigue montado: vuelve a desconectarlo."
elif mount | grep -q '/mnt/respaldo'; then
  no "El respaldo sigue montado en /mnt/respaldo: vuelve a desconectarlo."
else
  ok "Respaldo desmontado (desconectado otra vez)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Datos recuperados y verificados."; exit 0; } || exit 1
