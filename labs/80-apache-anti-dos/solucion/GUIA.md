# Resolución guiada · Lab 80

:::piensa Un flood gana agotando recursos
Apache atiende cada conexión con un *worker* (hilo o proceso), y tiene un
número limitado. Un flood HTTP no necesita romper nada: le basta con tenerlos
todos ocupados. El hardening ataca cada forma de ocuparlos: cortar a quien
envía la petición gota a gota (`mod_reqtimeout`), no esperar eternamente
(`Timeout`, `KeepAliveTimeout`) y frenar a quien repite demasiado
(`mod_evasive`). Ninguna medida sola basta: es **defensa en capas**.
:::

**El plan:** (0) medir, (1) cortar conexiones lentas, (2) bajar los tiempos
de espera, (3) frenar al que martillea, (4) validar y aplicar, y (5) medir otra
vez.

## Paso 0 · Mídelo antes

**Objetivo:** una cifra para comparar después.

:::pista Cómo hacerlo
```bash
ab -n 2000 -c 200 http://127.0.0.1/
```
**ab** (ApacheBench) lanza peticiones contra una URL: `-n 2000` en total,
`-c 200` a la vez. Fíjate en *Requests per second*, *Failed requests* y en
cuánto tarda el más lento (*longest request*).
:::

## Paso 1 · Cortar conexiones que no terminan

**Objetivo:** que quien abre una conexión y envía la petición muy despacio no
ocupe un worker indefinidamente.

:::pista Cómo hacerlo
```bash
sudo a2enmod reqtimeout
cat /etc/apache2/mods-enabled/reqtimeout.conf
```
`a2enmod` activa un módulo de Apache (crea el enlace en `mods-enabled/`). En
Debian, `reqtimeout.conf` ya trae una línea activa:
```apache
RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
```

| Parte | Qué significa |
|---|---|
| `header=20-40` | El cliente tiene 20 s para empezar a enviar las cabeceras; si va enviando, se amplía hasta 40 s como máximo. |
| `MinRate=500` | Cada 500 bytes recibidos dan 1 s más de margen. Por debajo de ese ritmo, se le corta. |
| `body=20,MinRate=500` | Lo mismo para el cuerpo de la petición. |

Es también la defensa contra Slowloris (lab 81), que abre muchas conexiones
y envía las cabeceras byte a byte.
:::

## Paso 2 · No regalar tiempo ni conexiones ociosas

**Objetivo:** que Apache no espere minutos a un cliente.

:::pista Cómo hacerlo
```bash
sudo nano /etc/apache2/apache2.conf
```
Cambia las líneas que ya existen:
```apache
Timeout 30
KeepAliveTimeout 5
```

| Directiva | Qué significa |
|---|---|
| `Timeout` | Cuánto espera Apache a que el cliente envíe o reciba datos en una operación. `300` son 5 minutos con un worker parado: un regalo para el atacante. 30 s sobran para un cliente real. |
| `KeepAliveTimeout` | Tras una respuesta, cuánto mantiene abierta la conexión esperando otra petición del mismo cliente. Con `65`, cada cliente que se va deja un worker ocupado más de un minuto. |
:::

## Paso 3 · Frenar al que martillea

**Objetivo:** bloquear temporalmente a una IP que hace demasiadas peticiones.

**Pregúntate:** ¿y si una IP pide 50 veces la misma página en un segundo?

:::pista Cómo hacerlo
```bash
sudo a2enmod evasive
sudo tee /etc/apache2/mods-enabled/evasive.conf >/dev/null <<'EOF'
<IfModule mod_evasive20.c>
    DOSHashTableSize    3097
    DOSPageCount        5
    DOSSiteCount        100
    DOSPageInterval     1
    DOSSiteInterval     1
    DOSBlockingPeriod   60
    DOSLogDir           "/var/log/apache2"
</IfModule>
EOF
```

| Directiva | Qué significa |
|---|---|
| `<IfModule mod_evasive20.c>` | Sólo se aplica si el módulo está cargado: así la config no rompe Apache si alguien lo desactiva. |
| `DOSPageCount 5` + `DOSPageInterval 1` | Más de 5 peticiones a la **misma** página en 1 s… |
| `DOSSiteCount 100` + `DOSSiteInterval 1` | …o más de 100 peticiones al sitio entero en 1 s… |
| `DOSBlockingPeriod 60` | …y esa IP recibe `403 Forbidden` durante 60 s. Cada petición durante el bloqueo **reinicia** la cuenta. |
| `DOSHashTableSize` | Tamaño de la tabla donde lleva la cuenta de cada IP. |
:::

## Paso 4 · Valida y aplica

```bash
sudo apache2ctl -t
sudo service apache2 restart
sudo apache2ctl -M | grep -Ei 'reqtimeout|evasive'
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/
bash /opt/lab/check.sh
```
`apache2ctl -t` comprueba la sintaxis sin tocar el servicio; `-M` lista los
módulos cargados. **Qué deberías ver:** `Syntax OK`, los dos módulos y un `200`.

## Paso 5 · Vuelve a medir (después de validar)

```bash
ab -n 2000 -c 200 http://127.0.0.1/
```
Ahora `ab` repite la misma página desde una sola IP: mod_evasive lo banea y
verás muchas respuestas rechazadas (*Non-2xx responses*), servidas muy rápido.

:::ojo Te acabas de banear a ti mismo
Tras el `ab`, `127.0.0.1` queda bloqueada 60 s, y cualquier petición en ese
tiempo alarga el bloqueo. Si ahora ejecutas `check.sh`, su `curl` recibe `403`
y falla "Apache no responde 200". Espera un minuto sin hacer peticiones y
vuelve a validar.
:::

## Cómo actuar en una situación así

- mod_evasive bloquea por IP: un flood **distribuido** (muchas IP, pocas
  peticiones cada una) lo esquiva. Por eso hacen falta también el reverse proxy
  (lab 83) y el WAF (lab 82).
- Ajusta el MPM (`mods-enabled/mpm_event.conf`, `MaxRequestWorkers`): muy alto
  agota la RAM; muy bajo te tumbas tú solo.
- No bajes `Timeout` tanto que corte subidas legítimas de ficheros grandes.
- Revisa `DOSLogDir` y `error.log`: ahí ves a quién se banea.

## Si te atascas

- **`apache2ctl -t` da error en `evasive.conf`:** revisa que el bloque
  `<IfModule …>` esté cerrado con `</IfModule>`.
- **El check dice que Apache no responde 200 justo después de un `ab`:** es el
  bloqueo de mod_evasive. Espera 60 s.
- **`Timeout` sigue en 300:** puede estar definido dos veces en
  `apache2.conf`; `grep -n '^Timeout' /etc/apache2/apache2.conf`.
