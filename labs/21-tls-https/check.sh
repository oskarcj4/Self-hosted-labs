#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 21.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 21 — comprobación =="

if [ -f /etc/tls/server.crt ] && openssl x509 -in /etc/tls/server.crt -noout 2>/dev/null; then
  ok "El certificado /etc/tls/server.crt existe y es válido."
else
  no "Falta un certificado válido en /etc/tls/server.crt."
fi

if [ -f /etc/tls/server.key ]; then
  ok "La clave privada /etc/tls/server.key existe."
else
  no "Falta la clave privada /etc/tls/server.key."
fi

if curl -sk --max-time 4 https://localhost:8443 | grep -q "https ok"; then
  ok "El servidor responde por HTTPS en el puerto 8443."
else
  no "El servidor HTTPS no responde en 8443 (¿lo arrancaste?)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 HTTPS en marcha. ¡Lab 21 resuelto!"; exit 0; } || exit 1
