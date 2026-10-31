#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 115.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 115 · Proceso minero: evidencia antes de actuar — comprobación =="
E=/home/analista/evidencia
REF=$($SUDO cat /opt/lab/.ref-sha256)
WALLET=$($SUDO cat /opt/lab/.ref-wallet)

if [ -d $E ]; then ok "Existe ~/evidencia/."; else no "No existe ~/evidencia/."; fi
FOUND=""
for f in $E/*; do
  [ -f "$f" ] || continue
  [ "$($SUDO sha256sum "$f" 2>/dev/null | cut -d' ' -f1)" = "$REF" ] && FOUND=$f
done
[ -n "$FOUND" ] && ok "Binario del proceso recuperado ($FOUND)." \
  || no "Falta una copia del binario en ~/evidencia/ (el original ya no está en disco: búscalo en /proc)."
if $SUDO grep -rqs "$REF" $E --include='*.txt' --include='*sha256*'; then ok "Hash SHA-256 anotado."; else no "Falta un fichero .txt con el SHA-256 del binario."; fi
if $SUDO grep -rqsa 'stratum+tcp' $E; then ok "Línea de comando guardada."; else no "Falta la línea de comando del proceso (/proc/PID/cmdline)."; fi
if $SUDO grep -rqsa "MINER_WALLET=$WALLET" $E; then ok "Entorno del proceso guardado."; else no "Falta el entorno del proceso (/proc/PID/environ)."; fi
if $SUDO grep -rqsE ':3333' $E; then ok "Conexiones de red guardadas."; else no "Faltan las conexiones del proceso (ss -tnp)."; fi
if $SUDO grep -rqsE 'kdevtmpfsi.*|load average' $E && $SUDO grep -rqs 'load average' $E; then ok "Foto de top guardada."; else no "Falta la salida de top -b -n1."; fi

if pgrep -f 'kdevtmpfsi|stratum' >/dev/null || systemctl is-active -q php-fpm-pool 2>/dev/null; then
  no "El minero sigue corriendo."
else
  ok "El minero está detenido."
fi
[ -e /tmp/.X11-cache ] && no "Queda el directorio oculto /tmp/.X11-cache." || ok "Directorio del minero retirado."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Evidencia a salvo y minero detenido."; exit 0; } || exit 1
