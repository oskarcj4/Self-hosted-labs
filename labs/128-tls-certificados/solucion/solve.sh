#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
for h in banco.lab caducado.lab autofirmado.lab intranet-vieja.lab banco-seguro-login.lab; do
  echo "== $h"
  echo | openssl s_client -connect 127.0.0.1:443 -servername $h 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
  curl -sS -o /dev/null https://$h 2>&1 || true
done
cat > /home/analista/tls.txt <<'T'
banco.lab=valido
caducado.lab=caducado
autofirmado.lab=autofirmado
intranet-vieja.lab=nombre_incorrecto
banco-seguro-login.lab=valido
phishing=banco-seguro-login.lab
emisor_banco=Empresa Lab CA Interna
T
chown analista:analista /home/analista/tls.txt
cd /root/ca
openssl req -new -key /etc/nginx/tls/caducado.key -subj "/CN=caducado.lab" \
  -addext "subjectAltName=DNS:caducado.lab" -out caducado-nuevo.csr
openssl x509 -req -in caducado-nuevo.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 90 -copy_extensions copy -out /etc/nginx/tls/caducado.crt
nginx -t && systemctl reload nginx && sleep 1
