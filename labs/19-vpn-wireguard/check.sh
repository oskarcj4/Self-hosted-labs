#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 19.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 19 — comprobación =="

if ip link show wg0 >/dev/null 2>&1; then
  ok "La interfaz wg0 existe."
else
  no "No existe la interfaz wg0."
fi

if [ -s /shared/lab.pub ]; then
  ok "Publicaste tu clave pública en /shared/lab.pub."
else
  no "Falta publicar tu clave pública en /shared/lab.pub."
fi

if wg show wg0 2>/dev/null | grep -q peer; then
  ok "wg0 tiene un peer configurado."
else
  no "wg0 no tiene ningún peer configurado."
fi

if ping -c1 -W3 10.8.0.2 >/dev/null 2>&1; then
  ok "El túnel funciona: ping 10.8.0.2 responde."
else
  no "No hay ping a 10.8.0.2 por el túnel (revisa claves, endpoint y allowed-ips)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 VPN establecida. ¡Lab 19 resuelto!"; exit 0; } || exit 1
