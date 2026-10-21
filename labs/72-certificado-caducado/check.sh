#!/usr/bin/env bash
# Validador del Lab 72. Mira el certificado que nginx SIRVE (no el fichero),
# y lo valida contra el almacén de confianza del sistema.
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
CA=/etc/pki/ca
SRV=$(mktemp)

echo "== Lab 72 · Certificado caducado — comprobación =="

openssl s_client -connect 127.0.0.1:443 -servername shop.local </dev/null 2>/dev/null \
  | openssl x509 > "$SRV" 2>/dev/null
if [ ! -s "$SRV" ]; then
  no "nginx no sirve ningún certificado en el 443."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

end=$(openssl x509 -in "$SRV" -noout -enddate | cut -d= -f2)
left=$(( ($(date -d "$end" +%s) - $(date +%s)) / 86400 ))
if [ "$left" -ge 80 ] && [ "$left" -le 91 ]; then
  ok "El certificado servido vence el $end (quedan $left días)."
else
  no "El certificado servido vence el $end ($left días): debe ser de 90 días."
fi

san=$(openssl x509 -in "$SRV" -noout -ext subjectAltName 2>/dev/null)
if echo "$san" | grep -q 'DNS:shop.local' && echo "$san" | grep -q 'DNS:www.shop.local'; then
  ok "subjectAltName incluye shop.local y www.shop.local."
else
  no "subjectAltName no incluye shop.local y www.shop.local (tiene: $(echo "$san" | tail -n +2 | xargs || true))."
fi

openssl verify -CAfile $CA/ca.crt "$SRV" >/dev/null 2>&1 \
  && ok "Lo firma la CA interna." || no "El certificado servido no verifica contra /etc/pki/ca/ca.crt."

serial=$(openssl x509 -in "$SRV" -noout -serial | cut -d= -f2)
awk -F'\t' -v s="$serial" '$1=="V" && $4==s' $CA/index.txt | grep -q . \
  && ok "Está en el registro de la CA (index.txt, serie $serial)." \
  || no "La serie $serial no está como válida en $CA/index.txt: emítelo con 'openssl ca'."

keyfp=$(openssl pkey -in /etc/nginx/tls/shop.key -pubout 2>/dev/null | sha256sum | cut -c1-16)
crtfp=$(openssl x509 -in "$SRV" -noout -pubkey | sha256sum | cut -c1-16)
oldfp=$(cat /var/lib/tclab/old-key.fp 2>/dev/null)
bits=$(openssl x509 -in "$SRV" -noout -text | grep -oE '(Public-Key: \([0-9]+ bit|NIST CURVE: P-256|ASN1 OID: prime256v1)' | head -1)
if [ "$keyfp" = "$crtfp" ]; then
  ok "La clave de /etc/nginx/tls/shop.key corresponde al certificado servido."
else
  no "/etc/nginx/tls/shop.key no corresponde al certificado servido."
fi
[ -n "$oldfp" ] && [ "$crtfp" != "$oldfp" ] && ok "Clave nueva (no se reutilizó la vieja)." \
  || no "El certificado nuevo usa la misma clave que el caducado."
case "$bits" in
  *"(2048 bit"*|*"(3072 bit"*|*"(4096 bit"*|*P-256*|*prime256v1*) ok "Clave aceptable: ${bits#Public-Key: (}." ;;
  *) no "Clave no aceptable (${bits:-desconocida}): RSA ≥ 2048 o ECDSA P-256." ;;
esac
p=$(stat -c '%a %U' /etc/nginx/tls/shop.key)
[ "$p" = "600 root" ] || [ "$p" = "400 root" ] && ok "La clave privada sólo la lee root ($p)." \
  || no "Permisos de la clave privada: $p (debe ser 600 o 400, de root)."

if curl -fs --max-time 5 https://shop.local/ | grep -q 'tienda segura' \
   && curl -fs --max-time 5 https://www.shop.local/ >/dev/null; then
  ok "curl https://shop.local y https://www.shop.local funcionan con la confianza del sistema."
else
  no "curl https://shop.local no funciona: $(curl -sS --max-time 5 -o /dev/null https://shop.local/ 2>&1 | head -1)"
fi

[ "$(cat /run/nginx.pid 2>/dev/null)" = "$(cat /var/lib/tclab/nginx-master.pid)" ] \
  && ok "nginx recargó el certificado sin reiniciarse (mismo proceso maestro)." \
  || no "El proceso maestro de nginx cambió: lo reiniciaste. Con 'systemctl reload nginx' no se cortan conexiones."
rm -f "$SRV"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Certificado renovado bien y en caliente. Ahora, a automatizarlo."; exit 0; } || exit 1
