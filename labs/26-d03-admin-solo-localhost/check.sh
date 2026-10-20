#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 26 (Día 03).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
IP=$(hostname -I | awk '{print $1}')

echo "== Lab 26 · Día 03 — comprobación =="

binds=$($SUDO ss -H -tln | awk '{print $4}' | grep -E ':9090$')
if [ -n "$binds" ] && ! echo "$binds" | grep -qvE '^(127\.0\.0\.1|\[::1\]):9090$'; then
  ok "ops-admin escucha sólo en loopback ($(echo $binds))."
else
  no "El 9090 no escucha sólo en 127.0.0.1 (ahora: ${binds:-nada})."
fi

if grep -qE '^\s*BIND_ADDR\s*=\s*"?127\.0\.0\.1"?\s*$' /etc/ops-admin/admin.conf 2>/dev/null; then
  ok "admin.conf fija BIND_ADDR=127.0.0.1 (persistente tras reinicios)."
else
  no "admin.conf no tiene BIND_ADDR=127.0.0.1."
fi

if systemctl is-active --quiet ops-admin && systemctl is-enabled --quiet ops-admin \
   && curl -s --max-time 3 http://127.0.0.1:9090/ | grep -q "ops-admin panel"; then
  ok "El panel sigue funcionando para uso local (curl 127.0.0.1:9090)."
else
  no "ops-admin no está activo/habilitado o no responde en 127.0.0.1:9090."
fi

if curl -s --max-time 3 "http://$IP:9090/" >/dev/null 2>&1; then
  no "El panel todavía responde desde la red en $IP:9090."
else
  ok "Desde la red ($IP:9090) el panel ya no es accesible."
fi

if curl -s --max-time 3 "http://$IP/admin/" | grep -q "ops-admin panel"; then
  no "El panel sigue accesible desde fuera a través de nginx (http://$IP/admin/)."
else
  ok "nginx ya no expone el panel en /admin/."
fi

if curl -s --max-time 3 "http://$IP/" | grep -q "Portal de operaciones"; then
  ok "El sitio público sigue respondiendo en http://$IP/."
else
  no "El sitio público ya no responde en http://$IP/."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Panel de admin confinado a localhost. ¡Día 03 resuelto!"; exit 0; } || exit 1
