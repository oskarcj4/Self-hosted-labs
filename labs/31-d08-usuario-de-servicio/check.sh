#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 31 (Día 08).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 31 · Día 08 — comprobación =="

if ! id reportd >/dev/null 2>&1; then
  no "No existe el usuario 'reportd'."
else
  uid=$(id -u reportd); shell=$(getent passwd reportd | cut -d: -f7)
  if [ "$uid" -lt 1000 ] && [ "$uid" -ne 0 ]; then ok "reportd es un usuario de sistema (uid $uid)."
  else no "reportd debería ser un usuario de sistema (uid < 1000 y distinto de 0; ahora $uid)."; fi
  case "$shell" in
    */nologin|*/false) ok "reportd no tiene shell de login ($shell)." ;;
    *) no "reportd tiene una shell interactiva ($shell): usa /usr/sbin/nologin." ;;
  esac
  if id -nG reportd | tr ' ' '\n' | grep -qxE 'sudo|root|adm|wheel|staff|disk|docker'; then
    no "reportd pertenece a un grupo privilegiado ($(id -nG reportd))."
  else
    ok "reportd no está en grupos privilegiados."
  fi
fi

if [ "$(systemctl show reportd -p User --value)" = "reportd" ]; then
  ok "La unidad declara User=reportd."
else
  no "La unidad reportd.service no declara User=reportd."
fi

pid=$(systemctl show reportd -p MainPID --value)
if systemctl is-active --quiet reportd && [ "${pid:-0}" -gt 0 ] && [ "$(ps -o user= -p "$pid" | tr -d ' ')" = "reportd" ]; then
  ok "El proceso en ejecución pertenece a reportd (PID $pid)."
else
  no "reportd no está activo o su proceso no corre como reportd."
fi

h=$(curl -s --max-time 3 http://127.0.0.1:8400/health)
if echo "$h" | grep -q "reportd ok user=reportd"; then
  ok "El servicio está sano (/health: ok, user=reportd)."
else
  no "/health no está sano: ${h:-sin respuesta}"
fi

sleep 6
newest=$($SUDO find /var/lib/reportd/reports -name 'report-*.txt' -newermt '-15 seconds' -user reportd 2>/dev/null | head -1)
if [ -n "$newest" ] && $SUDO grep -q "Ventas diarias" "$newest"; then
  ok "Sigue generando informes (con su configuración) como reportd."
else
  no "No hay informes recientes creados por reportd con el título de la configuración."
fi

if systemctl is-enabled --quiet reportd; then ok "reportd sigue habilitado al arranque."; else no "reportd ya no está habilitado."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 reportd ya no corre como root. ¡Día 08 resuelto!"; exit 0; } || exit 1
