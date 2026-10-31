# TLS: el candado no significa "legítimo"

> Redes · openssl s_client · openssl x509 · SNI · CA interna

## Escenario

Este proxy sirve cinco webs por HTTPS (`~/ticket/TLS-128.txt`). Toca
auditar sus certificados. Recuerda: el candado sólo dice que la conexión
está cifrada con **quien dice ser ese nombre**. No dice que ese nombre sea
de quien tú crees. Un phishing puede tener un certificado impecable.

Un certificado es válido si: lo firma una CA en la que confías, está dentro
de sus fechas (`notBefore`/`notAfter`) y el nombre que visitas está en su
`subjectAltName`.

## Objetivos

1. Inspecciona el certificado de cada web y clasifícalo en `~/tls.txt`:
   `valido`, `caducado`, `autofirmado` o `nombre_incorrecto`.
2. Identifica la web que, con un certificado válido, **no** es del banco
   (`phishing=`) y anota el CN del emisor del de `banco.lab`
   (`emisor_banco=`).
3. Renueva el certificado de `caducado.lab` firmándolo con la CA interna
   (`/root/ca`). Que dure más de 30 días y que `curl` funcione sin `-k`.

## Comandos que te pueden servir

```bash
echo | openssl s_client -connect 127.0.0.1:443 -servername banco.lab 2>/dev/null \
  | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
echo | openssl s_client -connect 127.0.0.1:443 -servername caducado.lab -verify_return_error
curl -v https://autofirmado.lab
sudo openssl req -new -key /etc/nginx/tls/caducado.key -subj "/CN=caducado.lab" \
  -addext "subjectAltName=DNS:caducado.lab" -out caducado.csr
sudo openssl x509 -req -in caducado.csr -CA /root/ca/ca.crt -CAkey /root/ca/ca.key \
  -CAcreateserial -days 90 -copy_extensions copy -out <destino>
sudo nginx -t && sudo systemctl reload nginx
```

> `-servername` envía el SNI: un mismo IP:443 sirve un certificado distinto
> según el nombre que pidas. Sin él, recibes el de la web por defecto.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
