# Resolución guiada · Lab 128

:::piensa Antes de tocar nada
El candado sólo dice que la conexión está cifrada con alguien que tiene un
certificado válido para ese nombre. No dice que ese alguien sea tu banco.
:::

## Paso 1 · Mira cada certificado

**Pregúntate:** un servidor con varias webs en el mismo puerto, ¿cómo sabe qué certificado darte? (SNI.)

:::pista Cómo comprobarlo
```bash
for h in banco.lab caducado.lab autofirmado.lab intranet-vieja.lab banco-seguro-login.lab; do
  echo "== $h"
  echo | openssl s_client -connect 127.0.0.1:443 -servername $h 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
done
```
:::

## Paso 2 · Clasifica

**Pregúntate:** para cada uno: ¿fechas válidas? ¿emisor de confianza o él mismo? ¿el SAN incluye el nombre visitado?

:::pista Cómo comprobarlo
```bash
curl -sS -o /dev/null https://caducado.lab
curl -sS -o /dev/null https://intranet-vieja.lab
```
`curl` da el motivo exacto del rechazo. Valores: `valido`, `caducado`, `autofirmado`, `nombre_incorrecto`.
:::

## Paso 3 · El phishing

**Pregúntate:** uno de los válidos no es del banco. ¿Cuál tiene un nombre que imita al real?

:::pista Qué anotar
En `~/tls.txt`: una línea por web, `phishing=` y `emisor_banco=` (el CN del emisor de `banco.lab`).
:::

## Paso 4 · Renueva el caducado

**Pregúntate:** ¿qué necesitas para firmar un certificado nuevo? CSR + CA + extensiones (SAN).

:::pista Cómo hacerlo
```bash
cd /root/ca     # con sudo -i
openssl req -new -key /etc/nginx/tls/caducado.key -subj "/CN=caducado.lab" \
  -addext "subjectAltName=DNS:caducado.lab" -out caducado-nuevo.csr
openssl x509 -req -in caducado-nuevo.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 90 -copy_extensions copy -out /etc/nginx/tls/caducado.crt
nginx -t && systemctl reload nginx
```
Sin `-copy_extensions copy` el SAN se pierde y los clientes modernos lo rechazan.
:::

## Cómo actuar en una situación así

- **Vigila caducidades** (monitor, `certbot renew`, alertas a 30 días).
- **El nombre importa más que el candado**: enseña a los usuarios a leer el dominio.
- Certificate Transparency (crt.sh) te avisa de certificados emitidos para nombres parecidos al tuyo.

## Si te atascas

- `s_client` se queda esperando: pon `echo |` delante.
- Tras renovar sigue caducado: falta recargar nginx.
