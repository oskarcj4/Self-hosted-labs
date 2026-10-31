#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 128.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
T=/home/analista/tls.txt
val(){ grep -E "^$1=" $T 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\r' | sed 's/^ *//; s/ *$//'; }

echo "== Lab 128 · TLS y certificados — comprobación =="
bad=""
for kv in banco.lab=valido caducado.lab=caducado autofirmado.lab=autofirmado intranet-vieja.lab=nombre_incorrecto banco-seguro-login.lab=valido; do
  [ "$(val ${kv%=*})" = "${kv#*=}" ] || bad="$bad ${kv%=*}"
done
[ -z "$bad" ] && ok "Estado de los 5 certificados correcto." || no "tls.txt: revisa el estado de:$bad"
[ "$(val phishing)" = banco-seguro-login.lab ] && ok "Phishing identificado: candado válido ≠ sitio legítimo." || no "tls.txt: phishing= no es la web correcta."
[ "$(val emisor_banco)" = "Empresa Lab CA Interna" ] && ok "Emisor de banco.lab leído del certificado." || no "tls.txt: emisor_banco= debe ser el CN del emisor (openssl x509 -issuer)."

if echo | openssl s_client -connect 127.0.0.1:443 -servername caducado.lab -verify_return_error >/dev/null 2>&1; then
  ok "caducado.lab vuelve a tener un certificado que verifica."
else
  no "caducado.lab sigue sin verificar (openssl s_client -verify_return_error)."
fi
end=$(echo | openssl s_client -connect 127.0.0.1:443 -servername caducado.lab 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$end" ] && [ "$(date -d "$end" +%s)" -gt "$(date -d '+30 days' +%s)" ]; then
  ok "El nuevo certificado de caducado.lab dura más de 30 días."
else
  no "El certificado de caducado.lab caduca en menos de 30 días (o no se pudo leer)."
fi
issuer=$(echo | openssl s_client -connect 127.0.0.1:443 -servername caducado.lab 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null)
echo "$issuer" | grep -q 'Empresa Lab CA Interna' && ok "Firmado por la CA interna (no autofirmado)." || no "El nuevo certificado debe firmarlo la CA interna."
curl -fs https://caducado.lab >/dev/null && ok "curl https://caducado.lab funciona sin -k." || no "curl https://caducado.lab sigue fallando."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Certificados auditados y renovado el caducado."; exit 0; } || exit 1
