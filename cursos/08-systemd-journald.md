# 08 · systemd y journald

> systemd arranca y vigila los servicios de casi todo Linux moderno. Aquí: qué es una unidad, cómo se lee y se escribe un `.service` y un `.timer`, el ciclo `daemon-reload` / `enable` / `start`, y cómo consultar los logs con `journalctl`.

## 1. Unidades: la pieza básica

systemd gestiona **unidades**. Cada una es un fichero de texto con formato INI. Los tipos que verás:

| Tipo | Para qué |
|---|---|
| `.service` | Un programa que corre (un demonio o un script de una vez) |
| `.timer` | Lanza una unidad (normalmente un `.service` del mismo nombre) según un horario |
| `.target` | Agrupa unidades: un "estado" del sistema, como `multi-user.target` |
| `.socket` | Escucha en un puerto y arranca el servicio al recibir conexión |
| `.mount`, `.path` | Montajes; vigilar cambios en ficheros |

### Dónde viven

| Carpeta | Quién pone ahí | Prioridad |
|---|---|---|
| `/lib/systemd/system/` (o `/usr/lib/systemd/system/`) | Los paquetes | Baja |
| `/etc/systemd/system/` | El administrador (o un intruso) | Alta: anula a la de `/lib` con el mismo nombre |
| `/etc/systemd/system/<unidad>.d/*.conf` | "Drop-ins": retocan una unidad sin copiarla | Se suman encima |
| `~/.config/systemd/user/` | Servicios de usuario | Sólo para esa cuenta |

Regla de auditoría: lo que está en `/etc/systemd/system/` lo puso alguien a mano. Empieza por ahí.

## 2. Leer y controlar servicios

```bash
systemctl status nombre          # estado, PID, últimas líneas de log
systemctl cat nombre             # el fichero de la unidad + sus drop-ins, con su ruta
systemctl show nombre -p ExecStart -p User -p Restart   # propiedades efectivas
systemctl is-enabled nombre      # ¿arranca en el boot?
systemctl is-active nombre       # ¿está corriendo ahora?
systemctl list-units --type=service --state=running
systemctl list-unit-files --state=enabled
```

### Leer `systemctl status`

```
● app.service - Mi aplicación
     Loaded: loaded (/etc/systemd/system/app.service; enabled; preset: enabled)
     Active: active (running) since Tue 2026-10-20 03:14:07 UTC; 2h ago
   Main PID: 812 (python3)
     CGroup: /system.slice/app.service
             └─812 /usr/bin/python3 /opt/app/app.py
```

- `Loaded`: de qué fichero sale (¡la ruta te dice si lo puso un paquete o una persona!) y si está `enabled`.
- `Active`: `active (running)`, `inactive (dead)`, `failed`, `activating (auto-restart)` (se cae y vuelve).
- `CGroup`: todos los procesos de ese servicio. Útil para saber qué servicio lanzó un proceso raro.

Al revés también funciona: dado un PID sospechoso, `systemctl status PID` te dice a qué unidad pertenece.

### Las acciones

| Comando | Efecto | ¿Persiste tras reiniciar? |
|---|---|---|
| `start` / `stop` | Arranca / para ahora | No |
| `restart` | Para y arranca | No |
| `reload` | Pide al servicio que relea su config sin parar (si lo soporta) | No |
| `enable` / `disable` | Crea / quita el enlace que lo arranca en el boot | Sí |
| `enable --now` / `disable --now` | Lo anterior **y** start / stop a la vez | Sí |
| `mask` / `unmask` | Lo bloquea: no se puede arrancar ni manualmente ni como dependencia | Sí |
| `daemon-reload` | Relee los ficheros de unidad del disco | |

> Trampa número uno de systemd: editas o creas un fichero de unidad y no pasa nada. systemd tiene las unidades **en memoria**: tras cualquier cambio en los ficheros, `sudo systemctl daemon-reload`. Si se te olvida, `systemctl status` te avisa con "Warning: unit file changed on disk".

Trampa número dos: `stop` sin `disable` no sobrevive a un reinicio, y `disable` sin `stop` deja el proceso corriendo hasta el reinicio. Para quitar algo del todo: `disable --now`.

## 3. Anatomía de un .service

```ini
[Unit]
Description=Mi aplicación
After=network.target            # orden: arráncame después de la red

[Service]
Type=simple                     # el proceso de ExecStart ES el servicio
User=app                        # no lo corras como root si no hace falta
WorkingDirectory=/opt/app
ExecStart=/usr/bin/python3 /opt/app/app.py
Restart=on-failure              # o always
RestartSec=5

[Install]
WantedBy=multi-user.target      # 'enable' lo engancha a este target
```

Lo esencial:

- `ExecStart` necesita **ruta absoluta** al ejecutable. No pasa por una shell: `>`, `|`, `&&` y `~` no funcionan ahí. Si los necesitas, `ExecStart=/bin/sh -c '...'` (y piensa si de verdad los necesitas).
- `Restart=always` lo relanza si muere por lo que sea; `on-failure` sólo si sale con error. Es justo lo que quieres para tu app y justo lo que usa un atacante para que su beacon "resucite".
- Sin sección `[Install]` con `WantedBy=`, `enable` no tiene a qué engancharse y avisa.
- `Type=simple` es lo habitual para un programa que se queda en primer plano. Si el programa se va a segundo plano por sí solo (hace "fork"), sería `Type=forking`; si es un script que hace algo y termina, `Type=oneshot`.

### Flujo para crear un servicio

```bash
sudoedit /etc/systemd/system/nombre.service     # crea el fichero
systemd-analyze verify /etc/systemd/system/nombre.service   # busca errores
sudo systemctl daemon-reload
sudo systemctl enable --now nombre.service
systemctl status nombre.service
journalctl -u nombre.service -n 30               # si falla, aquí está el porqué
```

## 4. Timers: el cron de systemd

Un `.timer` lanza la unidad con su mismo nombre (`backup.timer` lanza `backup.service`) o la que diga `Unit=`.

```ini
[Unit]
Description=Ejecutar cada 15 minutos

[Timer]
OnBootSec=1min            # 1 minuto después de arrancar
OnUnitActiveSec=15min     # y luego cada 15 minutos desde la última ejecución
# o con calendario: OnCalendar=*-*-* 03:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl list-timers --all     # todos los timers: siguiente y última ejecución
```

### Leer `list-timers`

```
NEXT                        LEFT     LAST                        PASSED  UNIT              ACTIVATES
Tue 2026-10-20 03:15:00 UTC 40s      Tue 2026-10-20 03:14:00 UTC 19s ago algo.timer        algo.service
Wed 2026-10-21 00:00:00 UTC 20h      Tue 2026-10-20 00:00:00 UTC 3h ago  logrotate.timer   logrotate.service
```

Un timer que se dispara cada minuto, con un nombre genérico ("health", "update", "sync") y un fichero en `/etc/systemd/system/` merece que mires qué `ACTIVATES` y luego `systemctl cat` de ese servicio.

### Quitar persistencia en systemd

La idea, en orden:

1. Identifica el par timer + servicio y lee qué ejecutan (`systemctl cat`).
2. Para y deshabilita **los dos** (si dejas el timer, vuelve a lanzar el servicio).
3. Borra los ficheros de unidad y cualquier enlace que quede en `/etc/systemd/system/*.wants/`.
4. `daemon-reload` para que systemd olvide las unidades.
5. Borra el payload que ejecutaban.
6. Confirma: `systemctl list-timers --all` y `systemctl status` ya no deberían conocerlas.

`systemctl reset-failed` limpia de la lista las unidades que quedaron en estado "failed".

## 5. journald: los logs de systemd

systemd recoge la salida de todos los servicios y los mensajes del kernel en el **journal**. Se consulta con `journalctl`:

```bash
journalctl -u nombre.service          # logs de un servicio
journalctl -u nombre -n 50            # las últimas 50 líneas
journalctl -u nombre -f               # en vivo (como tail -f)
journalctl --since '2026-10-20 03:00' --until '04:00'
journalctl --since '10 min ago'
journalctl -p err                     # sólo errores o peor
journalctl -b                         # desde el último arranque
journalctl -k                         # sólo kernel (como dmesg)
journalctl _UID=1000                  # todo lo que generó ese UID
journalctl _COMM=sshd                 # por nombre de programa
journalctl -o json-pretty -n 1        # ver todos los campos de una entrada
```

El journal se guarda en `/var/log/journal/` (persistente) o en `/run/log/journal/` (se pierde al reiniciar). En muchos Debian, además, `rsyslog` sigue escribiendo los ficheros de texto clásicos en `/var/log/`. Un atacante que vacía `/var/log/auth.log` puede olvidarse del journal, y al revés (módulo [09](#curso/09)).

> En los contenedores de los labs, systemd puede estar o no según el lab. Si `systemctl` dice "System has not been booted with systemd", ese lab no usa systemd y lo que manda es el proceso de arranque del contenedor.

## 6. Ejercicios

1. Creas `/etc/systemd/system/web.service`, haces `systemctl start web` y responde "Unit web.service not found". ¿Qué olvidaste?
2. ¿Qué diferencia hay entre `systemctl stop x` y `systemctl disable x`?
3. Un `ExecStart=python3 app.py > /var/log/app.log` no funciona. Da dos razones.
4. Tienes un PID sospechoso. ¿Cómo sabes si lo lanzó un servicio de systemd y cuál?

:::solucion Ver respuestas
1. `sudo systemctl daemon-reload`: systemd no ha leído el fichero nuevo.
2. `stop` lo para ahora pero vuelve en el próximo arranque si está enabled. `disable` lo quita del arranque pero no para lo que ya corre. `disable --now` hace ambas cosas.
3. No usa ruta absoluta (`/usr/bin/python3`, `/opt/.../app.py`) y la redirección `>` no funciona porque ExecStart no usa una shell. La salida ya va al journal: `journalctl -u`.
4. `systemctl status PID` muestra la unidad a la que pertenece. También `cat /proc/PID/cgroup`.
:::

## Chuleta

```bash
systemctl status|cat|show x; systemctl is-enabled x; systemctl list-timers --all
ls -la /etc/systemd/system/ /etc/systemd/system/*.wants/
sudo systemctl daemon-reload; sudo systemctl enable --now x; sudo systemctl disable --now x
systemd-analyze verify f.service
journalctl -u x -n 50; journalctl -f; journalctl --since '1 hour ago'; journalctl -p err -b
```
