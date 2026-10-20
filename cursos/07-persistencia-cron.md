# 07 · Persistencia: cron y escondites del atacante

> Persistencia es lo que hace que un intruso vuelva aunque cierres su sesión o mates su proceso. Aquí: cómo funciona cron, cómo se lee una línea de crontab y el inventario de sitios donde se esconde la persistencia en Linux.

## 1. La idea

Un atacante que consigue entrar quiere **seguir dentro** después de un reinicio, de un cambio de contraseña o de que alguien mate su proceso. Para eso deja algo que el sistema ejecuta solo:

- Al pasar el tiempo: cron, timers de systemd, `at`.
- Al arrancar la máquina: servicios de systemd, `rc.local`, scripts de init.
- Al iniciar sesión alguien: `.bashrc`, `.profile`, `/etc/profile.d/` (módulo [02](#curso/02)).
- Al conectarse: llaves en `authorized_keys` (módulo [12](#curso/12)), cuentas nuevas (módulo [04](#curso/04)).
- Al usar un comando: binarios impostores en el PATH, alias, SUID.

El defensor tiene que revisar **todos** los mecanismos, no sólo el primero que encuentre. Los atacantes suelen dejar dos o tres por si uno falla.

## 2. Cron: el programador clásico

El demonio `cron` despierta cada minuto, lee sus tablas y lanza lo que toca. Las tablas están en varios sitios:

| Ubicación | De quién | ¿Lleva columna de usuario? |
|---|---|---|
| `crontab -e` (se guarda en `/var/spool/cron/crontabs/<usuario>`) | De cada usuario | No: corre como ese usuario |
| `/etc/crontab` | Del sistema | Sí |
| `/etc/cron.d/*` | Del sistema y de paquetes | Sí |
| `/etc/cron.hourly/`, `daily/`, `weekly/`, `monthly/` | Scripts que se ejecutan con esa frecuencia | No son tablas: son scripts ejecutables |

### Leer una línea de crontab

```
*/5  3  *  *  1-5   root   /usr/local/bin/backup.sh >/dev/null 2>&1
 │   │  │  │   │     │     └ comando
 │   │  │  │   │     └ usuario (sólo en /etc/crontab y /etc/cron.d)
 │   │  │  │   └ día de la semana (0-7, 0 y 7 = domingo)
 │   │  │  └ mes (1-12)
 │   │  └ día del mes (1-31)
 │   └ hora (0-23)
 └ minuto (0-59)
```

| Sintaxis | Significa |
|---|---|
| `*` | Cualquier valor |
| `*/5` | Cada 5 |
| `1-5` | Del 1 al 5 |
| `1,15` | El 1 y el 15 |
| `@reboot` | Una vez al arrancar el demonio cron |
| `@hourly`, `@daily` | Atajos |

La línea del ejemplo: cada 5 minutos, durante la hora de las 3, de lunes a viernes, como root. `* * * * *` es "cada minuto": la frecuencia favorita de un beacon que quiere reaparecer en cuanto lo mates.

Fíjate también en el **final** de la línea: `>/dev/null 2>&1` tira toda la salida. Los trabajos legítimos también lo hacen, pero en uno malicioso sirve para que cron no mande correos de error que delaten el fallo.

### Cómo revisar todo cron

```bash
crontab -l                                  # el tuyo
sudo crontab -l                             # el de root
sudo crontab -l -u www-data                 # el de otro usuario
sudo ls -la /var/spool/cron/crontabs/       # quién tiene crontab propio
cat /etc/crontab
ls -la /etc/cron.d/ && cat /etc/cron.d/*
ls -la /etc/cron.{hourly,daily,weekly,monthly}/
```

Para cada línea que encuentres, pregúntate: ¿qué ejecuta?, ¿con qué usuario?, ¿ese fichero existe?, ¿quién puede modificarlo?, ¿desde cuándo está ahí (`ls -l --time-style=full-iso`)?

> Señales de alarma en cron: rutas en `/tmp`, `/dev/shm` o con punto inicial; `curl` o `wget` que descargan y ejecutan (`| sh`, `| bash`); cadenas en base64; nombres que imitan a paquetes (`apt-check`, `sys-update`); un fichero en `cron.d` que ningún paquete reclama (`dpkg -S`).

### Cron y los registros

Cron deja constancia en `/var/log/syslog` (o en el journal) cada vez que lanza algo:

```bash
grep CRON /var/log/syslog | tail
journalctl -u cron --since '1 hour ago'     # si hay systemd
```

Ver una línea `CRON[1234]: (root) CMD (/tmp/...)` es la confirmación de que esa tarea se está ejecutando.

### Neutralizar una tarea cron

- Una línea dentro de una tabla de usuario: `crontab -e` (o `sudo crontab -e -u usuario`) y bórrala.
- Un fichero en `/etc/cron.d/`: bórralo entero si todo él es del atacante. Si mezcla tareas legítimas, edita sólo la línea.
- No hace falta reiniciar cron: relee las tablas solo cada minuto.

Después, el orden de siempre: persistencia, proceso, binario (módulo [06](#curso/06)). Y espera un minuto para confirmar que no vuelve.

## 3. at: tareas de una sola vez

`at` programa algo para un momento concreto. Menos común, pero sirve para esconder una ejecución futura:

```bash
atq                   # cola de trabajos pendientes
at -c NUMERO          # contenido del trabajo
atrm NUMERO           # borrarlo
```

## 4. Inventario de escondites

Usa esta tabla como lista de comprobación cuando sospeches persistencia. Cada fila tiene su módulo.

| Mecanismo | Dónde mirar | Módulo |
|---|---|---|
| Cron | `/etc/crontab`, `/etc/cron.d/`, `/etc/cron.*/`, `/var/spool/cron/crontabs/` | 07 |
| Timers y servicios systemd | `systemctl list-timers --all`, `/etc/systemd/system/` | [08](#curso/08) |
| Arranque de shell | `~/.bashrc`, `~/.profile`, `~/.bash_profile`, `/etc/bash.bashrc`, `/etc/profile.d/` | [02](#curso/02) |
| Llaves SSH | `~/.ssh/authorized_keys` de cada usuario, incluido root | [12](#curso/12) |
| Cuentas | UID 0 extra, cuentas nuevas con shell, reglas de sudo | [04](#curso/04), [05](#curso/05) |
| Binarios | SUID nuevos, impostores en `/usr/local/bin`, alias | [02](#curso/02), [04](#curso/04) |
| Web | Ficheros nuevos o modificados en el web root (`/var/www`) | [09](#curso/09) |
| Carga de librerías | `/etc/ld.so.preload` (debería no existir o estar vacío) | Este módulo |

### Barrido de ficheros modificados recientemente

Si sabes aproximadamente cuándo fue la intrusión, los ficheros cambiados en esa ventana son tu mejor pista:

```bash
sudo find /etc /usr/local /var/spool/cron /tmp /dev/shm -xdev -newermt '2026-10-20 03:00' -type f 2>/dev/null
ls -la --time-style=full-iso /etc/cron.d/
```

`-newermt 'fecha'` casa los ficheros modificados después de esa fecha. Ten presente que la fecha de modificación se puede falsificar con `touch`; la de cambio de inodo (`ctime`, la que muestra `stat` como "Change") es más difícil de manipular.

## 5. Escondites en memoria y temporales

`/tmp`, `/var/tmp` y `/dev/shm` son escribibles por todos. `/dev/shm` además vive en RAM: lo que hay ahí desaparece al reiniciar y no deja rastro en disco. Por eso es el sitio favorito para dejar un payload que otro mecanismo (una línea en `.bashrc`, un cron) ejecuta.

```bash
ls -la /tmp /var/tmp /dev/shm
find /tmp /var/tmp /dev/shm -type f -perm -u+x 2>/dev/null    # ficheros ejecutables
mount | grep -E '/tmp|/dev/shm'                                 # ¿montados con noexec?
```

Montar estas carpetas con la opción `noexec` impide ejecutar binarios desde ahí. No para un `bash /dev/shm/x.sh` (el binario que se ejecuta es bash), pero sí el caso más simple.

## 6. Ejercicios

1. Traduce a palabras: `0 */2 * * * root /opt/bk.sh` y `@reboot /home/ana/.x`.
2. Una línea en `/etc/cron.d/` tiene sólo cinco campos de tiempo y el comando, sin usuario. ¿Qué pasa?
3. ¿Por qué no basta con matar un proceso si hay un cron que lo lanza cada minuto?
4. Has borrado una tarea cron. ¿Cómo confirmas que ya no se ejecuta?

:::solucion Ver respuestas
1. "Al minuto 0 de cada 2 horas, como root, ejecuta `/opt/bk.sh`." y "Cada vez que arranque cron, ejecuta `/home/ana/.x` como el dueño de esa crontab".
2. En `cron.d` el sexto campo es el usuario. Cron interpretará la primera palabra del comando como usuario, y la línea fallará o hará algo distinto de lo esperado. Revisa `syslog` en busca de errores de cron.
3. Porque al minuto siguiente cron lo vuelve a lanzar con un PID nuevo. Primero se quita el cron, después se mata el proceso.
4. Espera un par de minutos y comprueba que no aparecen nuevas líneas `CRON ... CMD` con ese comando en `syslog` o en el journal, y que el proceso no reaparece en `ps` ni su puerto en `ss`.
:::

## Chuleta

```bash
crontab -l; sudo crontab -l; sudo crontab -l -u usuario
cat /etc/crontab /etc/cron.d/*; ls -la /etc/cron.*/ /var/spool/cron/crontabs/
grep CRON /var/log/syslog | tail
atq; at -c N
ls -la /tmp /var/tmp /dev/shm
sudo find /etc /tmp /dev/shm -xdev -newermt 'AAAA-MM-DD HH:MM' -type f 2>/dev/null
cat /etc/ld.so.preload 2>/dev/null
```
