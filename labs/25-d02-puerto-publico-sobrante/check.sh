#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 25 (Día 02).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
IP=$(hostname -I | awk '{print $1}')

echo "== Lab 25 · Día 02 — comprobación =="

if $SUDO ss -H -tln | awk '{print $4}' | grep -qE ':8080$'; then
  no "Algo sigue escuchando en el puerto 8080."
else
  ok "Nada escucha ya en el puerto 8080."
fi

if $SUDO nginx -T 2>/dev/null | grep -vE '^\s*#' | grep -qE 'listen\s+[^;]*8080'; then
  no "La configuración efectiva de nginx (nginx -T) aún tiene un 'listen ... 8080': volvería al recargar."
else
  ok "La configuración de nginx ya no declara el 8080 (el cambio sobrevive a reinicios)."
fi

if $SUDO nginx -t >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
  ok "nginx tiene una configuración válida y está activo."
else
  no "nginx -t falla o nginx no está activo."
fi

if curl -s --max-time 3 "http://$IP/" | grep -q "Tienda Norte" \
   && curl -s --max-time 3 "http://$IP/css/style.css" | grep -q "font-family" \
   && [ "$(curl -s --max-time 3 "http://$IP/health")" = "ok" ]; then
  ok "La tienda sigue respondiendo en el puerto 80 desde la red ($IP)."
else
  no "La tienda no responde bien en http://$IP/ (índice, CSS o /health)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Puerto sobrante cerrado sin tocar la web. ¡Día 02 resuelto!"; exit 0; } || exit 1
