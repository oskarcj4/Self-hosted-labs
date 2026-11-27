# Resolución guiada · Healthcheck y autorrecuperación

:::piensa "Proceso vivo" no es "servicio funcionando"
systemd vigila el **proceso**: si muere, `Restart=on-failure` lo levanta.
Pero `catalog` no muere, se queda bloqueado. Para systemd todo va bien. Para
los clientes, nada responde. Hace falta alguien que mire lo que ve el cliente
(`/health`) y actúe. Y la trampa número uno: si ese "alguien" espera la
respuesta sin límite, se queda bloqueado con `catalog`.
:::

**El plan:** (1) reproducir el cuelgue, (2) escribir el script que
comprueba, reinicia y avisa, (3) programarlo cada 15 s con un timer de systemd
y (4) probarlo con un cuelgue real.

## Paso 1 · Reproduce el cuelgue

**Objetivo:** ver con tus ojos que systemd no detecta nada y que sólo una
petición con límite de tiempo lo delata.

:::pista Cómo hacerlo
```bash
sudo touch /run/catalog/hang                    # el lab simula el deadlock con este fichero
systemctl is-active catalog
curl -s --max-time 3 http://127.0.0.1:8300/health; echo "exit=$?"
```
- `--max-time 3`: si en 3 s no ha terminado, `curl` aborta.
- `$?` es el código de salida del último comando: `0` = bien, otro = fallo.

**Qué deberías ver:** `active` (systemd cree que todo va bien) y, tras 3 s,
`exit=28`. El 28 es el código de `curl` para "se acabó el tiempo". Prueba el
mismo `curl` **sin** `--max-time`: se queda colgado hasta que pulses Ctrl+C.
Eso es lo que le pasaría a tu watchdog.

Deja `catalog` sano para seguir:
```bash
sudo systemctl restart catalog
```
Al reiniciar, systemd borra y recrea `/run/catalog/` (`RuntimeDirectory=` en
la unidad), así que el fichero `hang` desaparece solo.
:::

## Paso 2 · El script del watchdog

**Objetivo:** un script que, en cada ejecución, compruebe `/health` y, sólo
si falla, reinicie y avise.

**Pregúntate:** ¿qué cuenta como "falla"? ¿Sólo que no responda, o también
que responda con un error? ¿Y qué `PATH` tendrá cuando lo lance systemd o cron?

:::pista Cómo hacerlo
```bash
sudo tee /usr/local/bin/catalog-watchdog.sh >/dev/null <<'EOF'
#!/bin/bash
set -u
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
URL=http://127.0.0.1:8300/health

curl -fs --max-time 3 -o /dev/null "$URL" && exit 0

logger -t catalog-watchdog "catalog no responde; reiniciando"
systemctl restart catalog
curl -s --max-time 5 -X POST \
  --data "catalog: /health sin respuesta en 3 s; reiniciado por el watchdog ($(hostname) $(date '+%F %T'))" \
  http://127.0.0.1:9000/alert >/dev/null || logger -t catalog-watchdog "fallo al enviar alerta"
EOF
sudo chmod 755 /usr/local/bin/catalog-watchdog.sh
```

| Pieza | Por qué está ahí |
|---|---|
| `set -u` | Si usas una variable que no existe (una errata en `$URL`), el script se para con un error en vez de seguir con un valor vacío. |
| `export PATH=…` | systemd y cron lanzan los scripts con un `PATH` mínimo. Fijarlo aquí garantiza que encuentra `curl`, `systemctl` y `logger` vengan de donde vengan. |
| `curl -f` | Trata una respuesta HTTP de error (500, 503…) como fallo. Sin `-f`, `curl` sale con 0 aunque el servidor responda 500. |
| `curl -s -o /dev/null` | Sin barra de progreso y tirando el cuerpo de la respuesta: sólo nos importa si salió bien o mal. |
| `… && exit 0` | Si el `curl` va bien, termina aquí sin hacer nada. Todo lo de debajo sólo se ejecuta si ha fallado. |
| `logger -t catalog-watchdog "…"` | Escribe un mensaje en el log del sistema con esa etiqueta. Luego lo encuentras con `journalctl -t catalog-watchdog`. |
| `curl -X POST --data "…"` | Envía el texto de la alerta en el cuerpo de un `POST` al receptor (`curl -s localhost:9000` te enseña el formato que espera). |
| `\|\| logger …` | Si el envío de la alerta falla, que al menos quede escrito en el log. |

La alerta va **después** del reinicio: lo urgente es recuperar el servicio;
avisar puede esperar un segundo.

Pruébalo a mano, con el mismo entorno mínimo que usará el validador:
```bash
sudo env -i PATH=/usr/bin:/bin /usr/local/bin/catalog-watchdog.sh; echo "exit=$?"
```
`env -i` arranca el comando con el entorno **vacío** (salvo lo que le pases):
es la forma de imitar cómo lo lanzaría systemd o cron. **Qué deberías ver:**
`exit=0` y ninguna alerta nueva (`catalog` está sano).
:::

## Paso 3 · Que se ejecute solo cada 15 s

**Objetivo:** lanzar el script periódicamente, también después de un
reinicio de la máquina.

**Pregúntate:** cron tiene resolución de un minuto. El ticket pide 30 s como
mucho. ¿Qué otra forma tiene systemd de programar tareas?

:::pista Cómo hacerlo
Un **timer** de systemd son dos ficheros: un `.service` que dice **qué**
ejecutar y un `.timer` con el mismo nombre que dice **cuándo**.
```bash
sudo tee /etc/systemd/system/catalog-watchdog.service >/dev/null <<'EOF'
[Unit]
Description=Watchdog de catalog

[Service]
Type=oneshot
ExecStart=/usr/local/bin/catalog-watchdog.sh
TimeoutStartSec=60
EOF
sudo tee /etc/systemd/system/catalog-watchdog.timer >/dev/null <<'EOF'
[Unit]
Description=Lanza el watchdog de catalog cada 15 s

[Timer]
OnBootSec=30s
OnUnitActiveSec=15s
AccuracySec=1s

[Install]
WantedBy=timers.target
EOF
```

| Directiva | Qué significa |
|---|---|
| `Type=oneshot` | El servicio es una tarea que se ejecuta y termina, no un demonio que se queda vivo. |
| `TimeoutStartSec=60` | Si el script tardara más de 60 s, systemd lo mata. Es una red de seguridad por si algo se cuelga. |
| `OnBootSec=30s` | Primera ejecución 30 s después de arrancar la máquina. Si la máquina ya lleva más tiempo encendida, se ejecuta en cuanto actives el timer. |
| `OnUnitActiveSec=15s` | Cada ejecución siguiente, 15 s después de la anterior. Sin un `OnBootSec` (o similar) que lo arranque, este contador nunca empieza. |
| `AccuracySec=1s` | Por defecto systemd agrupa timers con hasta 1 min de margen para ahorrar energía. Aquí queremos precisión. |
| `WantedBy=timers.target` | Hace que `enable` lo active en cada arranque. |

Una ventaja frente a cron: si una ejecución sigue en marcha, systemd no lanza
otra encima.

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now catalog-watchdog.timer
systemctl list-timers catalog-watchdog.timer
```
`daemon-reload` hace que systemd lea los ficheros nuevos. `enable --now` lo
deja activado para los arranques futuros **y** lo arranca ya.

**Qué deberías ver:** en `list-timers`, una columna `NEXT` a menos de 15 s y
`LAST` con la ejecución anterior. Se activa el **timer**, no el `.service`:
el timer es quien lanza el servicio.
:::

## Paso 4 · Pruébalo con un cuelgue real

```bash
sudo touch /run/catalog/hang
watch -n1 'systemctl show catalog -p MainPID; curl -s --max-time 1 http://127.0.0.1:8300/health'
```
`watch -n1 'comando'` repite el comando cada segundo y refresca la pantalla
(sal con Ctrl+C). `systemctl show catalog -p MainPID` imprime sólo el PID del
proceso principal: si cambia, es que se reinició.

**Qué deberías ver:** durante unos segundos, sin respuesta; luego el `MainPID`
cambia y vuelve `catalog ok`. Después:
```bash
sudo tail /var/log/alerts/alerts.log            # la alerta que mandó tu watchdog
journalctl -t catalog-watchdog -n 5             # lo que escribió con logger
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Monitoriza desde fuera** (lo que ve el cliente), no sólo que el proceso exista.
- **Todo healthcheck lleva timeout.**
- En producción, exige **N fallos seguidos** antes de reiniciar (para no
  reaccionar a un pico puntual) y limita los reinicios por hora (para no
  entrar en bucle).
- systemd tiene su propio mecanismo, `WatchdogSec=` con `sd_notify WATCHDOG=1`,
  pero requiere que la app colabore.
- Un watchdog es una tirita: el bug del deadlock sigue abierto.

## Si te atascas

- **El watchdog nunca actúa:** falta `--max-time` en el `curl` (se cuelga con
  catalog), o activaste el `.service` en vez del `.timer`.
  `systemctl list-timers` debe mostrarlo.
- **`list-timers` no muestra `NEXT`:** falta `OnBootSec=` y sólo tienes
  `OnUnitActiveSec=`, que necesita una primera ejecución para empezar a contar.
- **Reinicia pero no llega la alerta:** revisa el `POST` a `:9000/alert` y
  `journalctl -u catalog-watchdog`.
- **El check dice que con catalog sano reinició o alertó:** probablemente te
  falta `-f` o el `&& exit 0`, y el script sigue hacia abajo aunque `/health`
  vaya bien.
