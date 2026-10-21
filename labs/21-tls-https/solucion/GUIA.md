# Resolución guiada · Lab 21

:::piensa Antes de tocar nada
TLS se apoya en dos piezas: una **clave privada** (secreta, sólo el servidor) y un **certificado** (público: dice "esta clave pertenece a este nombre"). El servidor presenta el certificado y demuestra que tiene la clave. Para un laboratorio vale un certificado autofirmado; en producción lo firma una CA en la que los clientes confían.
:::

## Paso 1 · ¿Qué espera el servidor?

**Pregúntate:** ¿dónde busca el servidor la clave y el certificado? Lo dice el enunciado: `/etc/tls/server.key` y `/etc/tls/server.crt`. En un caso real, lo leerías en su configuración.

:::pista Cómo comprobarlo
```bash
grep -n 'tls\|crt\|key' /opt/lab/tlsserver.py
```
:::

## Paso 2 · Genera el par

**Pregúntate:** ¿qué datos necesita un certificado? Como mínimo, un nombre (`CN`) y una validez.

:::pista Cómo hacerlo
```bash
sudo mkdir -p /etc/tls
sudo openssl req -x509 -newkey rsa:2048 -nodes \
     -keyout /etc/tls/server.key -out /etc/tls/server.crt \
     -days 365 -subj "/CN=web-21"
sudo chmod 600 /etc/tls/server.key
```
- `-x509`: certificado autofirmado (no una petición para una CA).
- `-nodes`: la clave no lleva contraseña (el servicio tiene que arrancar sin que nadie la escriba).
:::

## Paso 3 · Inspecciona lo que has creado

**Pregúntate:** ¿cómo compruebo que el certificado dice lo que quiero?

```bash
openssl x509 -in /etc/tls/server.crt -noout -subject -dates
```

## Paso 4 · Arranca y prueba

:::pista Cómo hacerlo
```bash
sudo python3 /opt/lab/tlsserver.py &
curl -k https://localhost:8443
bash /opt/lab/check.sh
```
`-k` le dice a curl "acepta un certificado que no firma ninguna CA de confianza". Sólo para pruebas.
:::

## Cómo actuar en una situación así

- **La clave privada es `600`** y no sale del servidor.
- **Nunca normalices `-k`** fuera de un laboratorio: anula la protección contra suplantación.
- En producción: certificado de una CA (Let's Encrypt), renovación automática, TLS 1.2+ y redirección de HTTP a HTTPS.
- Diagnóstico: `openssl s_client -connect host:puerto` muestra el certificado que presenta el servidor.

## Si te atascas

- El servidor no arranca: comprueba que ambos ficheros existen y que lo lanzas con `sudo` (la clave es `600` de root).
