#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 111.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 111 · Línea base contra rootkits — comprobación =="
PS=$(dpkg -L procps | grep -E '/bin/ps$' | head -1)

if $SUDO debsums -s procps >/dev/null 2>&1; then
  ok "Los ficheros de procps coinciden con el paquete oficial (debsums)."
else
  no "debsums todavía marca ficheros de procps como modificados."
fi
if head -c2 "$PS" | grep -q '#!'; then
  no "$PS sigue siendo un script, no el binario oficial."
else
  ok "$PS es el binario ELF oficial."
fi
if systemctl is-active -q kswapd-upd 2>/dev/null || pgrep -f kswapd-upd >/dev/null; then
  no "El proceso que ocultaba el troyano sigue vivo."
else
  ok "El proceso oculto ya no corre."
fi
if [ -e /usr/local/sbin/kswapd-upd ] || [ -e /usr/lib/x86_64-linux-gnu/libprocps-cache.so.0 ]; then
  no "Quedan artefactos del troyano en disco (qué ejecutaba el script y qué proceso escondía)."
else
  ok "Artefactos del troyano retirados."
fi

DAT=/var/lib/rkhunter/db/rkhunter.dat
REAL=$(sha256sum "$PS" | cut -d' ' -f1)
if $SUDO test -s $DAT && $SUDO grep -q "$PS:$REAL" $DAT; then
  ok "La línea base de rkhunter existe y registra el ps oficial."
else
  no "No hay línea base de rkhunter, o se tomó con el ps troyanizado (repite rkhunter --propupd con el sistema sano)."
fi
if $SUDO grep -q "Rootkit checks" /var/log/rkhunter.log 2>/dev/null; then
  ok "Hay un análisis completo de rkhunter en /var/log/rkhunter.log."
else
  no "No veo un rkhunter --check completo en /var/log/rkhunter.log."
fi
if [ -s /mnt/offsite/rkhunter.dat ] && $SUDO cmp -s /mnt/offsite/rkhunter.dat $DAT; then
  ok "Copia de la línea base guardada fuera del servidor (/mnt/offsite)."
else
  no "Falta /mnt/offsite/rkhunter.dat idéntico a la línea base actual."
fi
if ls /mnt/offsite/ 2>/dev/null | grep -q 'rkhunter.*\.log' && ls /mnt/offsite/ | grep -qi chkrootkit; then
  ok "Reportes de rkhunter y chkrootkit guardados en /mnt/offsite."
else
  no "Guarda en /mnt/offsite el log de rkhunter (*rkhunter*.log) y la salida de chkrootkit (*chkrootkit*)."
fi
INF=/mnt/offsite/informe.txt
if [ -s $INF ] && grep -q "$PS" $INF && grep -qi 'falso positivo' $INF; then
  ok "informe.txt documenta el hallazgo real y clasifica los falsos positivos."
else
  no "Falta /mnt/offsite/informe.txt con el hallazgo real ($PS) y los warnings que son 'falso positivo'."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Línea base limpia y a salvo fuera del servidor."; exit 0; } || exit 1
