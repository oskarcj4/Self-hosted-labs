# Resolución guiada · Lab 80

:::piensa Antes de tocar nada
Un flood HTTP gana por **agotar recursos**: conexiones, workers, memoria. El hardening de Apache ataca cada frente: cortar conexiones que no avanzan (reqtimeout), no regalar tiempo (Timeout/KeepAlive bajos) y frenar a quien repite demasiado (mod_evasive). Ninguna medida sola basta; es **defensa en capas**.
:::

## Paso 0 · Mídelo antes

**Pregúntate:** ¿cómo sé si mejora? Mide primero.

```bash
ab -n 2000 -c 200 http://127.0.0.1/     # fíjate en "Failed requests" y "Requests per second"
```

## Paso 1 · Cortar conexiones que no terminan

**Pregúntate:** ¿qué hago con quien abre conexión y envía la petición gota a gota?

:::pista Cómo hacerlo
```bash
sudo a2enmod reqtimeout
# en /etc/apache2/mods-enabled/reqtimeout.conf (descomenta/añade):
RequestReadTimeout header=20-40,MinRate=500 body=20,MinRate=500
```
Esto mata al que no envía las cabeceras en 20-40 s o por debajo de 500 B/s. (Es, además, la base contra Slowloris: lab 81.)
:::

## Paso 2 · No regalar tiempo ni conexiones ociosas

:::pista Cómo hacerlo
```bash
# en /etc/apache2/apache2.conf
Timeout 30
KeepAliveTimeout 5
MaxKeepAliveRequests 100
```
`Timeout 300` significa esperar 5 minutos a un cliente lento: un regalo para el atacante. 30 s es de sobra para un cliente real.
:::

## Paso 3 · Frenar al que martillea (mod_evasive)

**Pregúntate:** ¿y si una IP pide 50 veces la misma página en 1 segundo?

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
Si una IP pide la **misma** página >5 veces/s o >100 peticiones/s al sitio, la banea 60 s con un 403.
:::

## Paso 4 · Validar y aplicar

```bash
sudo apache2ctl -t                 # Syntax OK
sudo service apache2 restart
sudo apache2ctl -M | grep -Ei 'reqtimeout|evasive'
bash /opt/lab/check.sh
```

## Paso 5 · Vuelve a medir

```bash
ab -n 2000 -c 200 http://127.0.0.1/   # ahora el atacante repetitivo recibe 403 rápido
```

## Cómo actuar en una situación así

- **mod_evasive** es un cortafuegos de aplicación básico por IP: útil, pero un flood **distribuido** (muchas IPs, pocas peticiones cada una) lo esquiva. Por eso necesitas también el reverse proxy (lab 83) y el WAF (lab 82).
- Ajusta el MPM (`/etc/apache2/mods-enabled/mpm_event.conf`): `MaxRequestWorkers`, `ThreadsPerChild`. Demasiado alto agota RAM; demasiado bajo te tumbas tú solo.
- Monitoriza `DOSLogDir` y `error.log`: ahí verás a quién banea.
- No pongas `Timeout` tan bajo que mates subidas legítimas de ficheros grandes.
