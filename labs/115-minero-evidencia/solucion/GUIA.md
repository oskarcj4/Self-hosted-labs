# Resolución guiada · Lab 115

:::piensa Antes de tocar nada
Matar el proceso es lo fácil, y destruye evidencia: el binario puede estar
borrado del disco y sólo existir en memoria, y la conexión al pool desaparece.
Primero se recoge lo volátil; después se actúa.
:::

Orden: **medir → identificar → copiar evidencia volátil → detener la persistencia → borrar**.

## Paso 1 · ¿Quién quema la CPU?

**Pregúntate:** el nombre dice `php-fpm`. ¿Coincide con un php-fpm real?

:::pista Cómo comprobarlo
```bash
uptime; nproc
top -b -n1 | head -15
ps aux --sort=-%cpu | head -5
```
:::

## Paso 2 · ¿Qué es en realidad?

**Pregúntate:** ¿qué datos de un proceso no puede falsificar con su nombre?

:::pista Cómo comprobarlo
```bash
ls -l /proc/<PID>/exe
tr '\0' ' ' < /proc/<PID>/cmdline; echo
sudo tr '\0' '\n' < /proc/<PID>/environ
sudo ss -tnp | grep "pid=<PID>"
ps -o unit= -p <PID>
```
:::

## Paso 3 · Guarda la evidencia

**Pregúntate:** si `exe` apunta a un fichero `(deleted)`, ¿cómo lo recuperas?

:::pista Cómo hacerlo
```bash
E=~/evidencia; mkdir -p $E
sudo cp /proc/<PID>/exe $E/binario
sha256sum $E/binario > $E/sha256.txt
# más: uptime.txt, top.txt, ps.txt, exe.txt, cmdline.txt, environ.txt, conexiones.txt
```
`/proc/PID/exe` sigue leyéndose mientras el proceso viva, aunque el fichero esté borrado.
:::

## Paso 4 · Ahora sí, erradica

**Pregúntate:** si lo lanza una unidad con `Restart=always`, ¿qué pasa si sólo haces `kill`?

:::pista Cómo hacerlo
```bash
sudo systemctl stop <unidad>; sudo systemctl disable <unidad>
sudo rm -rf /tmp/.X11-cache
```
:::

## Cómo actuar en una situación así

- **Orden de volatilidad**: memoria y conexiones antes que disco.
- **Hash de todo** lo que copies; anota hora y comando.
- Bloquea el pool en el firewall y busca la misma IP en el resto de servidores.

## Si te atascas

- `environ` da permiso denegado: usa `sudo`.
- El proceso vuelve tras `kill`: está gestionado por systemd; mira `ps -o unit=`.
