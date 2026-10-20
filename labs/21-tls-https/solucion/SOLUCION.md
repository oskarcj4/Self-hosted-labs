# Solución — Lab 21

## 1. Generar certificado + clave

```bash
sudo mkdir -p /etc/tls
sudo openssl req -x509 -newkey rsa:2048 -nodes \
     -keyout /etc/tls/server.key -out /etc/tls/server.crt \
     -days 365 -subj "/CN=web-21"
sudo chmod 600 /etc/tls/server.key
openssl x509 -in /etc/tls/server.crt -noout -subject -dates
```

## 2. Arrancar el servidor HTTPS

```bash
sudo python3 /opt/lab/tlsserver.py &
```

## 3. Verificar

```bash
curl -k https://localhost:8443       # https ok
# inspecciona el handshake y el certificado:
openssl s_client -connect localhost:8443 -servername web-21 </dev/null 2>/dev/null \
  | openssl x509 -noout -subject -issuer
bash /opt/lab/check.sh
```

## Lecciones

- TLS = clave privada (secreta, 600) + certificado (público). El servidor presenta
  el certificado; el cliente valida la cadena de confianza.
- Autofirmado sirve para labs/internos; en producción usa una CA (Let's Encrypt)
  para que los clientes confíen sin `-k`.
- Buenas prácticas: TLS 1.2+ únicamente, cifrados fuertes, renovación automática,
  y redirigir HTTP (80) a HTTPS (443).
