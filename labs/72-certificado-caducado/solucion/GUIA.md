# Resolución guiada · Certificado TLS caducado

:::piensa Antes de tocar nada
Dos problemas en uno: el certificado está caducado **y** no tiene
`subjectAltName`. Si sólo renuevas fechas, `www.shop.local` seguiría fallando
(los clientes modernos ignoran el CN). La CA interna vive aquí: emite una clave
nueva, firma con `openssl ca` para que quede en el registro (`index.txt`), y
recarga nginx **en caliente** (`reload`, no `restart`: hay conexiones largas).
:::

## Paso 1 · Diagnóstico

```bash
openssl s_client -connect 127.0.0.1:443 -servername shop.local </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
# notAfter=... (ayer) ; "No extensions in certificate"  -> caducado y sin SAN
```

## Paso 2 · Clave y CSR nuevas (con SAN)

:::pista Cómo hacerlo
```bash
cd /tmp
openssl req -new -newkey rsa:2048 -nodes \
  -keyout shop-2026.key -out shop-2026.csr \
  -subj "/O=TerminalCero/CN=shop.local" \
  -addext "subjectAltName=DNS:shop.local,DNS:www.shop.local"
openssl req -in shop-2026.csr -noout -text | grep -A1 'Alternative Name'
```
:::

## Paso 3 · Firmar con la CA (que quede registrado)

**Pregúntate:** ¿cómo firmo para que entre en `index.txt` y dure 90 días?

:::pista Cómo hacerlo
```bash
sudo openssl ca -config /etc/pki/ca/openssl.cnf -days 90 -in shop-2026.csr -out shop-2026.crt
# revisa y responde 'y' dos veces
sudo tail -2 /etc/pki/ca/index.txt
openssl x509 -in shop-2026.crt -noout -dates -ext subjectAltName
```
`copy_extensions = copy` pasa el SAN de la CSR al certificado; cómodo, pero
**obliga a revisar cada CSR** antes de firmar (copiaría un SAN indebido).
:::

## Paso 4 · Instalar y recargar en caliente

**Pregúntate:** ¿`reload` o `restart`? Hay conexiones largas → `reload`.

:::pista Cómo hacerlo
```bash
sudo cp /etc/nginx/tls/shop.crt /etc/nginx/tls/shop.crt.caducado    # backup antes
sudo install -m 0600 -o root -g root /tmp/shop-2026.key /etc/nginx/tls/shop.key
sudo install -m 0644 -o root -g root /tmp/shop-2026.crt /etc/nginx/tls/shop.crt
shred -u /tmp/shop-2026.key; rm -f /tmp/shop-2026.csr /tmp/shop-2026.crt
sudo nginx -t && sudo systemctl reload nginx
curl https://shop.local/ ; curl https://www.shop.local/
```
`reload` (SIGHUP) relee config y certificados, levanta workers nuevos y deja
terminar a los viejos; si la config está mal, nginx sigue con la anterior.
`restart` cortaría todo y, con config mala, dejaría nginx caído. Por eso
`nginx -t` siempre.
:::

## Paso 5 · Que no vuelva a pasar

```bash
openssl x509 -in /etc/nginx/tls/shop.crt -noout -checkend $((30*86400)) || echo "¡RENOVAR!"
bash /opt/lab/check.sh
```
Mételo en un timer que alerte (lab 64), o automatiza la emisión (ACME/certbot,
step-ca, cert-manager) con certificados cortos que se renuevan solos.

## Cómo actuar en una situación así

- **Un certificado caducado es un incidente anunciado**: la fecha se sabía al
  emitirlo.
- **SAN siempre**; el CN no basta desde hace años.
- **Clave nueva en cada renovación.**
- **`nginx -t && systemctl reload nginx`**, nunca `restart` con conexiones vivas.
- **Una CA interna necesita su `index.txt`** para saber qué emitió y poder
  revocar.

## Si te atascas

- `www.shop.local` sigue fallando → faltó el SAN; revisa `-addext` y
  `copy_extensions`.
- `curl` pide `-k` → el certificado no lo firmó la CA de confianza, o no
  recargaste nginx.
