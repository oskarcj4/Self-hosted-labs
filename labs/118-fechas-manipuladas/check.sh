#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 118.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 118 · Fechas manipuladas — comprobación =="
F=/home/analista/fechas.txt
for p in /usr/local/bin/backup-sync /usr/local/bin/rotate-logs; do
  grep -qF "$p" $F 2>/dev/null && ok "fechas.txt incluye $p." || no "~/fechas.txt no menciona un fichero tocado hoy (busca por ctime)."
done
if grep -qE '/usr/local/bin/(backup-db|healthcheck|clean-tmp)' $F 2>/dev/null; then
  no "fechas.txt incluye scripts legítimos que no se tocaron (falsos positivos)."
else
  ok "Sin falsos positivos en fechas.txt."
fi
grep -qE "$(date +%F)|$(date +%H):[0-5][0-9]" $F 2>/dev/null && ok "Anotaste el ctime real (de hoy)." || no "Anota el ctime real (stat: Change) de cada fichero."

[ -e /usr/local/bin/backup-sync ] && no "/usr/local/bin/backup-sync sigue en su sitio." || ok "Script del intruso retirado de /usr/local/bin."
if [ "$(sha256sum /usr/local/bin/rotate-logs | cut -d' ' -f1)" = "$($SUDO cat /opt/lab/.ref-rotate)" ]; then
  ok "rotate-logs restaurado al contenido del despliegue."
else
  no "rotate-logs no coincide con la copia del despliegue (/var/backups/usr-local-bin.tar.gz)."
fi
[ -x /usr/local/bin/rotate-logs ] && ok "rotate-logs sigue siendo ejecutable (lo llama cron)." || no "rotate-logs no existe o no es ejecutable."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 El ctime no miente: intrusión localizada y revertida."; exit 0; } || exit 1
