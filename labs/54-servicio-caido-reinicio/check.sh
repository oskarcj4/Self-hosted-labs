#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 54. Comprueba el estado real de systemd y la respuesta HTTP.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 54 · Servicio caído tras reinicio — comprobación =="

if $SUDO nginx -t >/dev/null 2>&1; then
  ok "La configuración de nginx es válida (nginx -t)."
else
  no "nginx -t falla: revisa el error que muestra."
fi

if ls /etc/nginx/sites-enabled/ 2>/dev/null | grep -qvE '^[A-Za-z0-9_-]+$'; then
  no "En sites-enabled/ hay ficheros que no son sitios (copias .bak, .old...): nginx los carga todos."
else
  ok "sites-enabled/ sólo contiene sitios activos."
fi

for s in nginx shop-api; do
  if [ "$(systemctl is-active "$s")" = active ]; then ok "$s está en marcha."
  else no "$s no está activo."; fi
  if [ "$(systemctl is-enabled "$s" 2>/dev/null)" = enabled ]; then ok "$s arranca solo en el próximo reinicio."
  else no "$s no está habilitado: tras el próximo reinicio volverá a caer."; fi
done

if curl -fsS --max-time 3 http://127.0.0.1/ 2>/dev/null | grep -q "Tienda online"; then
  ok "La portada responde por nginx."
else
  no "http://127.0.0.1/ no devuelve la portada de la tienda."
fi
if curl -fsS --max-time 3 http://127.0.0.1/api/health 2>/dev/null | grep -q "shop-api ok"; then
  ok "/api/ llega a la API a través del proxy."
else
  no "http://127.0.0.1/api/health no llega a shop-api a través de nginx."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Tienda de vuelta y preparada para el próximo reinicio."; exit 0; } || exit 1
