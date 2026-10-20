#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 16.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 16 — comprobación =="

if systemctl cat myapp.service >/dev/null 2>&1; then
  ok "La unidad myapp.service existe."
else
  no "No existe la unidad myapp.service."
fi

if [ "$(systemctl is-enabled myapp.service 2>/dev/null)" = "enabled" ]; then
  ok "myapp.service está habilitado (arrancará en el boot)."
else
  no "myapp.service no está habilitado (usa 'systemctl enable')."
fi

if systemctl is-active --quiet myapp.service 2>/dev/null; then
  ok "myapp.service está activo."
else
  no "myapp.service no está activo (usa 'systemctl start')."
fi

if curl -s --max-time 3 localhost:8000 | grep -q "myapp ok"; then
  ok "La app responde en el puerto 8000."
else
  no "La app no responde en el puerto 8000."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 App servicializada. ¡Lab 16 resuelto!"; exit 0; } || exit 1
