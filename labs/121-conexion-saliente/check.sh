#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 121.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 121 · Conexión saliente sospechosa — comprobación =="
C=/home/analista/conexion.txt
miss=""
for k in 198.51.100.66 6667 /var/tmp/.dbus/dbus-sync dbus-sync.service; do grep -qF "$k" $C 2>/dev/null || miss="$miss $k"; done
[ -z "$miss" ] && ok "conexion.txt documenta IP, puerto, binario y unidad." || no "A ~/conexion.txt le falta:$miss"

if ss -tn state established 2>/dev/null | grep -q '198.51.100.66:6667'; then no "Sigue habiendo conexión hacia 198.51.100.66:6667."; else ok "No hay conexión con el C2."; fi
if systemctl is-active -q dbus-sync 2>/dev/null || systemctl is-enabled -q dbus-sync 2>/dev/null; then
  no "dbus-sync.service sigue activo o habilitado (lo relanzará)."
else
  ok "La unidad que lo relanzaba está parada y deshabilitada."
fi
[ -e /etc/systemd/system/dbus-sync.service ] && no "El fichero de unidad sigue en /etc/systemd/system/." || ok "Unidad retirada."
[ -e /var/tmp/.dbus/dbus-sync ] && no "El binario sigue en /var/tmp/.dbus/." || ok "Binario retirado de /var/tmp."
if $SUDO iptables -S OUTPUT 2>/dev/null | grep -E -- '-d 198\.51\.100\.66(/32)? .*-j (DROP|REJECT)' >/dev/null; then
  ok "La IP del C2 está bloqueada en salida."
else
  no "Falta bloquear 198.51.100.66 en la cadena OUTPUT."
fi
if timeout 3 bash -c 'exec 3<>/dev/tcp/198.51.100.66/6667' 2>/dev/null; then no "Aún se puede abrir conexión con el C2."; else ok "Prueba de conexión al C2: bloqueada."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 C2 cortado y documentado."; exit 0; } || exit 1
