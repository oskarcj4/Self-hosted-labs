# Solución — TLS: el candado no es legitimidad

## Qué pasaba

| Web | Estado |
|---|---|
| `banco.lab` | válido (CA interna) |
| `caducado.lab` | caducado |
| `autofirmado.lab` | autofirmado |
| `intranet-vieja.lab` | certificado emitido para `intranet.lab`: nombre incorrecto |
| `banco-seguro-login.lab` | válido, pero es phishing |

## Arreglo

```bash
cat > ~/tls.txt <<'T'
banco.lab=valido
caducado.lab=caducado
autofirmado.lab=autofirmado
intranet-vieja.lab=nombre_incorrecto
banco-seguro-login.lab=valido
phishing=banco-seguro-login.lab
emisor_banco=Empresa Lab CA Interna
T
sudo -i
cd /root/ca
openssl req -new -key /etc/nginx/tls/caducado.key -subj "/CN=caducado.lab" \
  -addext "subjectAltName=DNS:caducado.lab" -out caducado-nuevo.csr
openssl x509 -req -in caducado-nuevo.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 90 -copy_extensions copy -out /etc/nginx/tls/caducado.crt
nginx -t && systemctl reload nginx
exit
bash /opt/lab/check.sh
```

## Más allá del lab

- Automatiza renovaciones (ACME/certbot, cert-manager) en lugar de firmar a mano.
- Una CA interna debe tener su clave fuera del servidor web.
- HSTS evita que alguien rebaje la conexión a HTTP.
