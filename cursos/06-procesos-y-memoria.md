# 06 · Procesos y memoria

> Qué es un proceso, cómo leer `ps` y `top`, por qué `/proc` dice la verdad cuando las herramientas mienten, cómo encontrar de dónde sale un proceso y cómo pararlo sin que vuelva.

## 1. Qué es un proceso

Un proceso es un programa en ejecución. El kernel le da:

- Un **PID** (número único mientras vive) y un **PPID** (el PID de su padre: quién lo lanzó).
- Un usuario (UID) con el que corre: decide qué puede tocar.
- Memoria propia, ficheros abiertos, variables de entorno, un directorio de trabajo.
- Un **nombre** (`comm`) y una **línea de comandos** (`cmdline`). Ambos los puede elegir el propio proceso: no son de fiar.

Todos los procesos forman un árbol cuyo origen es el PID 1 (`systemd`, `init`, o en un contenedor el programa de arranque). Saber quién es el padre de un proceso sospechoso dice **cómo** llegó ahí: lanzado por cron, por un servicio, por una sesión SSH.

## 2. Ver procesos: ps

`ps` tiene dos sintaxis. Las dos sirven:

```bash
ps aux                  # estilo BSD: todos los procesos, con usuario y consumo
ps -ef                  # estilo System V: todos, con PPID
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head    # columnas a medida
ps -ef --forest         # árbol con sangría
pstree -p               # árbol más visual (si está instalado)
```

### Leer la salida de `ps aux`

```
USER   PID %CPU %MEM    VSZ   RSS TTY  STAT START  TIME COMMAND
www    812 98.7  0.2  12340  4100 ?    R    03:14 52:10 /usr/bin/algo --flag
```

| Columna | Qué es |
|---|---|
| `%CPU` | Uso medio de CPU desde que arrancó. 100 = un núcleo entero |
| `%MEM` | Porcentaje de RAM física que usa |
| `VSZ` | Memoria virtual reservada (KB). Suele ser grande y engaña |
| `RSS` | Memoria **real** en RAM (KB). La que importa |
| `TTY` | Terminal asociada. `?` = sin terminal (demonio, cron, servicio) |
| `STAT` | Estado: `R` corriendo, `S` durmiendo, `D` esperando disco, `Z` zombi, `T` parado |
| `START` / `TIME` | Cuándo arrancó / tiempo de CPU acumulado |
| `COMMAND` | La línea de comandos que el proceso **dice** tener |

Los nombres entre corchetes, como `[kworker/0:1]`, son **hilos del kernel**: no tienen binario en disco ni línea de comandos. Un proceso de usuario puede llamarse a sí mismo `kworker` para camuflarse, pero no puede tener los corchetes de verdad ni dejar de tener ejecutable.

### Buscar procesos

```bash
pgrep -a nombre        # PIDs y líneas de comandos que contienen 'nombre'
pgrep -x nombre        # nombre EXACTO (sin -x, 'ssh' casa con 'sshd')
pgrep -u www-data      # por usuario
pidof sshd             # PIDs de un programa
```

## 3. top y htop: consumo en vivo

```bash
top            # q sale, P ordena por CPU, M por memoria, k mata, 1 muestra cada núcleo
top -b -n 1 | head -20   # una sola foto, útil para copiar en un informe
```

La cabecera de `top`:

```
load average: 3.12, 2.80, 1.40
%Cpu(s): 97.0 us,  1.0 sy,  0.0 ni,  2.0 id,  0.0 wa
MiB Mem :   3900.0 total,    210.0 free,   1200.0 used,   2490.0 buff/cache
```

- **load average**: procesos esperando CPU, media de 1, 5 y 15 minutos. Por encima del número de núcleos (`nproc`), la máquina va saturada.
- `us` usuario, `sy` kernel, `id` ocioso, `wa` esperando disco. Mucho `us` sostenido sin motivo = algo calcula sin parar (minería, bucle).
- **free** bajo no significa problema: Linux usa la RAM libre como caché (`buff/cache`) y la devuelve cuando hace falta. Mira `available` en `free -h`.

## 4. /proc: la fuente de verdad

`/proc` no es una carpeta en disco: es una ventana que el kernel genera al vuelo. Cada proceso tiene `/proc/<PID>/`. Herramientas como `ps` y `top` **leen de aquí**. Si una herramienta está manipulada (un script que filtra líneas, un `ps` sustituido), `/proc` sigue diciendo la verdad.

| Entrada | Qué te dice | Cómo leerla |
|---|---|---|
| `exe` | Enlace al binario **real** que se ejecuta | `ls -l /proc/PID/exe` |
| `cmdline` | Línea de comandos, separada por bytes NUL | `tr '\0' ' ' < /proc/PID/cmdline` |
| `comm` | Nombre corto (lo que ve `ps -o comm`) | `cat /proc/PID/comm` |
| `cwd` | Directorio de trabajo | `ls -l /proc/PID/cwd` |
| `environ` | Variables de entorno al arrancar (sólo dueño o root) | `tr '\0' '\n' < /proc/PID/environ` |
| `status` | Estado, UID, PPID, memoria | `grep -E 'PPid\|Uid\|VmRSS' /proc/PID/status` |
| `fd/` | Ficheros, sockets y pipes abiertos | `ls -l /proc/PID/fd` |
| `maps` | Librerías y zonas de memoria cargadas | `cat /proc/PID/maps` |

### Señales de impostor

- `exe` apunta a `/tmp`, `/dev/shm`, `/var/tmp` o a una ruta con un punto inicial.
- `exe` termina en `(deleted)`: el binario se borró del disco tras arrancar. El proceso sigue vivo y puedes **recuperar** el binario copiando `/proc/PID/exe` a otro sitio, por ejemplo para analizarlo.
- El nombre dice "kworker", "systemd-xyz" o "sshd", pero `exe` apunta a un intérprete de Python o a un ELF fuera de `/usr`.
- Un proceso de sistema cuyo padre es una shell o cron, o que corre con un usuario que no le corresponde.

```bash
for p in $(pgrep -x nombre); do echo "$p -> $(readlink /proc/$p/exe)"; done
ls -l /proc/*/exe 2>/dev/null | grep -E '/tmp/|/dev/shm/|deleted'   # barrido general (mejor con sudo)
```

> Cuando la salida de una herramienta te parezca rara, compárala con otra fuente. Si `sysmon` dice 0 % y `top` dice 100 %, uno de los dos miente. `cat /proc/loadavg` y `ls /proc/[0-9]*` no pasan por ningún script intermedio. Y mira **qué es** la herramienta: `type -a`, `file`, `cat` si es un script.

## 5. Procesos y red

Un proceso con un puerto abierto se ve en `ss` (módulo [10](#curso/10)) con su PID:

```bash
sudo ss -tulpn             # puertos en escucha y qué proceso los tiene
sudo ss -tnp               # conexiones establecidas con su proceso
sudo lsof -p PID           # todo lo que tiene abierto un proceso (si lsof está)
sudo lsof -i :4444         # qué proceso usa el puerto 4444
ls -l /proc/PID/fd | grep socket   # sockets sin lsof
```

## 6. Parar procesos: señales

`kill` no mata: **envía una señal**. El proceso decide qué hacer con casi todas.

| Señal | Número | Efecto |
|---|---|---|
| `SIGTERM` | 15 | "Termina, por favor". Por defecto de `kill`. El proceso puede limpiar o ignorarla |
| `SIGKILL` | 9 | El kernel lo elimina. No se puede ignorar ni capturar |
| `SIGHUP` | 1 | Tradicionalmente "recarga la configuración" para demonios |
| `SIGSTOP` / `SIGCONT` | 19 / 18 | Congela / reanuda. Útil para pararlo **sin perderlo** mientras investigas |

```bash
kill PID             # SIGTERM
kill -9 PID          # SIGKILL si no responde
kill -STOP PID       # congelarlo: deja de hacer daño pero sigue ahí para analizar
pkill -x nombre      # por nombre exacto (cuidado: puede matar a varios)
pkill -f 'patrón'    # por línea de comandos completa (aún más cuidado)
```

> Trampa: `pkill -f python` mata **todo** lo que tenga "python" en la línea de comandos, incluidos servicios legítimos. Antes, ejecuta `pgrep -af 'patrón'` y mira qué casaría.

### Por qué un proceso "resucita"

Matar un proceso no quita lo que lo vuelve a lanzar. Si aparece de nuevo con otro PID al minuto, hay algo que lo arranca: un cron, un timer de systemd, un servicio con `Restart=always`, una línea en un `.bashrc`, un proceso padre que lo vigila. El PPID del proceso nuevo y su `etime` (tiempo vivo) te dan la pista.

Orden correcto en un incidente:

1. **Observa y documenta**: PID, PPID, usuario, `exe`, `cmdline`, conexiones. Copia el binario si lo vas a borrar y lo quieres analizar.
2. **Quita la persistencia** (módulos [07](#curso/07) y [08](#curso/08)).
3. **Mata el proceso.**
4. **Borra el binario** y lo que deje.
5. **Espera** un ciclo del mecanismo de persistencia (por ejemplo 1 o 2 minutos) y vuelve a mirar.

## 7. Memoria

```bash
free -h                     # total, usada, disponible. Mira 'available'
vmstat 1 5                  # memoria, swap, CPU cada segundo, 5 veces
ps -eo pid,rss,cmd --sort=-rss | head    # los que más RAM real usan
cat /proc/meminfo | head    # la fuente de free
dmesg | grep -i 'killed process'         # el OOM killer mató algo por falta de memoria
```

Cuando la RAM se agota del todo, el kernel elige un proceso y lo mata (OOM killer). Queda registrado en `dmesg` y en el journal. Si un servicio "se cae solo" sin error en su log, mira ahí.

Los procesos **zombi** (`Z`) ya terminaron y sólo esperan a que su padre recoja el código de salida. No consumen CPU ni RAM; muchos zombis indican un padre mal programado. No se pueden matar: se arreglan matando o reiniciando al padre.

## 8. Ejercicios

1. Un proceso se llama `[kthreadd]` en `ps`, pero `ls -l /proc/PID/exe` apunta a `/var/tmp/.x`. ¿Qué concluyes?
2. ¿Qué diferencia hay entre `kill PID` y `kill -9 PID`? ¿Cuándo usarías `kill -STOP`?
3. Matas un proceso y a los 60 segundos hay otro igual con un PID nuevo. ¿Qué tres sitios miras primero?
4. Escribe un comando que muestre los 5 procesos con más memoria real, con su usuario.

:::solucion Ver respuestas
1. Es un impostor. Un hilo del kernel real no tiene `exe`. El nombre lo puso el propio proceso para camuflarse.
2. `kill` pide terminar (SIGTERM, ignorable); `-9` lo elimina el kernel (SIGKILL). `-STOP` para congelarlo mientras recoges evidencia sin que siga actuando.
3. Tareas cron (`/etc/cron.d`, `crontab -l` de cada usuario), timers y servicios de systemd (`systemctl list-timers`), y el PPID del proceso nuevo para ver quién lo lanzó.
4. `ps -eo user,pid,rss,cmd --sort=-rss | head -6`
:::

## Chuleta

```bash
ps -eo pid,ppid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head
ps -ef --forest; pgrep -ax nombre
ls -l /proc/PID/exe; tr '\0' ' ' < /proc/PID/cmdline; ls -l /proc/PID/cwd
grep -E 'PPid|Uid' /proc/PID/status
sudo ss -tulpn; sudo lsof -p PID
kill PID; kill -9 PID; kill -STOP PID; pgrep -af patrón
free -h; vmstat 1 5; dmesg | grep -i killed
```
