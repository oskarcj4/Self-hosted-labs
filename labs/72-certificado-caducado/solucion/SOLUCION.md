# Solución — Certificado TLS caducado

## 1. Diagnóstico

```bash
openssl s_client -connect 127.0.0.1:443 -servername shop.local </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
# subject=O = TerminalCero, CN = shop.local
# issuer=O = TerminalCero, CN = TerminalCero CA Interna
# notAfter=... (ayer)
# No extensions in certificate      <- ¡tampoco tiene SAN!
```

Dos problemas: está caducado y no tiene `subjectAltName`. Si sólo cambias las
fechas, `www.shop.local` seguiría fallando, y los clientes modernos ignoran
el CN.

## 2. Clave y CSR nuevas

```bash
cd /tmp
openssl req -new -newkey rsa:2048 -nodes \
  -keyout shop-2026.key -out shop-2026.csr \
  -subj "/O=TerminalCero/CN=shop.local" \
  -addext "subjectAltName=DNS:shop.local,DNS:www.shop.local"
openssl req -in shop-2026.csr -noout -text | grep -A1 'Alternative Name'
```

## 3. Firmar con la CA (que quede en el registro)

```bash
sudo openssl ca -config /etc/pki/ca/openssl.cnf -days 90 \
     -in shop-2026.csr -out shop-2026.crt
# Revisa lo que vas a firmar y responde 'y' dos veces.
sudo tail -2 /etc/pki/ca/index.txt     # V  <fecha>  <serie>  unknown  /O=TerminalCero/CN=shop.local
openssl x509 -in shop-2026.crt -noout -dates -ext subjectAltName
```

`copy_extensions = copy` en `openssl.cnf` hace que el SAN de la CSR pase al
certificado. Es cómodo, pero obliga a revisar cada CSR antes de firmarla:
si alguien pide un SAN que no le toca, lo copiaría igual.

## 4. Instalar y recargar en caliente

```bash
sudo install -m 0600 -o root -g root /tmp/shop-2026.key /etc/nginx/tls/shop.key
sudo install -m 0644 -o root -g root /tmp/shop-2026.crt /etc/nginx/tls/shop.crt
shred -u /tmp/shop-2026.key; rm -f /tmp/shop-2026.csr /tmp/shop-2026.crt
sudo nginx -t && sudo systemctl reload nginx
curl https://shop.local/ ; curl https://www.shop.local/
```

`reload` envía `SIGHUP`. El proceso maestro relee la configuración y los
certificados, arranca workers nuevos, y deja que los viejos terminen sus
conexiones. `restart` lo corta todo. Y si la config está mal, `reload` deja
nginx funcionando con la config anterior; `restart` lo deja caído. Por eso
siempre `nginx -t` primero.

Copia de seguridad del par viejo, por si acaso: `cp shop.crt shop.crt.caducado`
**antes** de sobrescribir.

## 5. Que no vuelva a pasar

```bash
# ¿Caduca en menos de 30 días?
openssl x509 -in /etc/nginx/tls/shop.crt -noout -checkend $((30*86400)) || echo "¡RENOVAR!"
```

Ponlo en un timer que alerte (como el watchdog del lab 64), o mejor:
automatiza la emisión (ACME con certbot o step-ca, o cert-manager en
Kubernetes) con certificados cortos que se renuevan solos.

## Lecciones

- Un certificado caducado es un incidente **anunciado**: se sabía la fecha
  desde el día en que se emitió.
- SAN siempre. El CN no basta desde hace años.
- Clave nueva en cada renovación.
- `nginx -t && systemctl reload nginx`.
- Una CA interna también necesita su registro (`index.txt`) para saber qué
  se emitió y poder revocarlo.
