#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 66. Mira los límites del proceso en marcha (/proc/PID/limits),
# no los ficheros de configuración.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 66 · Too many open files — comprobación =="

grep -qxE 'LimitNOFILE=64' /etc/systemd/system/ingest.service \
  && ok "La unit original no se ha tocado." \
  || no "Editaste /etc/systemd/system/ingest.service: la política pide un drop-in."
dropin=$(grep -lsE '^LimitNOFILE=' /etc/systemd/system/ingest.service.d/*.conf | head -1)
[ -n "$dropin" ] && ok "Drop-in con LimitNOFILE: $dropin" \
  || no "No hay ningún drop-in en /etc/systemd/system/ingest.service.d/ con LimitNOFILE=."

lim=$(systemctl show -p LimitNOFILE --value ingest)
if [ "$lim" = infinity ]; then
  no "LimitNOFILE=infinity: sin límite, una fuga de descriptores se lleva la máquina entera. Usa 4096."
elif [ "${lim:-0}" -ge 4096 ] 2>/dev/null; then
  ok "systemd aplica LimitNOFILE=$lim a ingest."
else
  no "systemd aplica LimitNOFILE=${lim:-?} a ingest (mínimo 4096). ¿daemon-reload?"
fi

echo "  (observando ingest 6 s...)"
p0=$(systemctl show -p MainPID --value ingest); sleep 6; p1=$(systemctl show -p MainPID --value ingest)
if systemctl is-active --quiet ingest && [ "$p0" = "$p1" ] && [ "$p1" != 0 ]; then
  ok "ingest activo y estable."
  soft=$($SUDO awk '/^Max open files/ {print $4}' /proc/$p1/limits)
  [ "${soft:-0}" -ge 4096 ] 2>/dev/null && ok "El proceso en marcha tiene $soft descriptores (/proc/$p1/limits)." \
    || no "El proceso en marcha sólo tiene ${soft:-?} descriptores: ¿lo reiniciaste?"
  nfd=$($SUDO ls /proc/$p1/fd 2>/dev/null | wc -l)
  [ "$nfd" -ge 500 ] && ok "ingest tiene $nfd descriptores abiertos (los 500 lotes)." \
    || no "ingest sólo tiene $nfd descriptores abiertos."
else
  no "ingest no está activo y estable ($(systemctl is-active ingest))."
fi

[ "$(systemctl is-enabled ingest)" = enabled ] && ok "ingest habilitado." || no "ingest no está habilitado."

h=$(curl -s --max-time 3 http://127.0.0.1:8600/health)
[ "$h" = "ingest ok 500 lotes" ] && ok "/health: $h" || no "/health no responde 'ingest ok 500 lotes' (responde: ${h:-nada})."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Límite de descriptores corregido donde de verdad aplica."; exit 0; } || exit 1
