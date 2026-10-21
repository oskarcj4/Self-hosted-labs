# Certificado TLS caducado

> Operaciones · TLS · openssl · CA interna · nginx reload

## Escenario

Desde esta mañana, `https://shop.local` da error en los navegadores y en el
monitor: `certificate has expired`. El certificado lo emite la **CA interna**,
que vive en este mismo servidor (`/etc/pki/ca`). Lee
`~/ticket/INC-7212.txt`.

## Objetivos

Un certificado nuevo para la tienda que:

1. Cubre `shop.local` **y** `www.shop.local` en `subjectAltName`.
2. Usa una **clave nueva** (RSA ≥ 2048 o ECDSA P-256), legible sólo por root.
3. Dura **90 días** y lo firma la CA interna con `openssl ca`, para que quede
   en su registro (`index.txt`).
4. nginx lo sirve **sin reiniciarse** (hay clientes con conexiones largas).
5. `curl https://shop.local/` funciona sin `-k`.

## Comandos que te pueden servir

```bash
curl -v https://shop.local/ 2>&1 | grep -iE 'expire|subject|issuer|SSL'
openssl s_client -connect 127.0.0.1:443 -servername shop.local </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
sudo cat /etc/pki/ca/openssl.cnf ; sudo cat /etc/pki/ca/index.txt
openssl req -new -newkey ... -nodes -keyout ... -out ... -subj ... -addext "subjectAltName=..."
sudo openssl ca -config /etc/pki/ca/openssl.cnf -in <csr> -out <crt>
openssl x509 -in <crt> -noout -text
sudo nginx -t && sudo systemctl reload nginx
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
