# Lab 21 — Sirve la app por HTTPS con TLS

## Escenario (tarea de operaciones)

`web-21` sirve una app en texto plano. Hay que ponerla detrás de **TLS**: generar
un certificado, colocarlo donde el servidor lo espera y arrancar el servicio en
HTTPS (puerto **8443**). Para el lab usamos un certificado **autofirmado** (en
producción sería de una CA / Let's Encrypt).

## Objetivos

1. **Genera un par certificado + clave** autofirmado y colócalos en
   `/etc/tls/server.crt` y `/etc/tls/server.key`.
2. **Arranca el servidor TLS** (`/opt/lab/tlsserver.py`), que los lee y escucha en
   el puerto 8443.
3. **Verifica** que responde por HTTPS (`curl -k https://localhost:8443`).

## Comandos que te pueden servir

```bash
sudo mkdir -p /etc/tls
sudo openssl req -x509 -newkey rsa:2048 -nodes \
     -keyout /etc/tls/server.key -out /etc/tls/server.crt \
     -days 365 -subj "/CN=web-21"
sudo chmod 600 /etc/tls/server.key
sudo python3 /opt/lab/tlsserver.py &        # arranca en :8443
curl -k https://localhost:8443
openssl x509 -in /etc/tls/server.crt -noout -subject -dates
```

> `-k` en curl acepta el certificado autofirmado. En producción no se usa `-k`:
> el certificado lo firma una CA en la que el cliente confía.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
