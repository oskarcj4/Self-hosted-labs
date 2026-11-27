# Resolución guiada · Lab 115

:::piensa Lo volátil primero
`kill -9` y a otra cosa destruye lo que forense necesita: el binario puede
estar ya borrado del disco y existir sólo en memoria, y la conexión con el
pool de minado desaparece con el proceso. El orden es **medir → identificar →
copiar lo volátil → detener lo que lo relanza → borrar**.
:::

**El plan:** (1) confirmar la carga y el proceso, (2) averiguar qué es,
(3) guardar la evidencia y (4) erradicarlo.

## Paso 1 · ¿Quién quema la CPU?

:::pista Cómo hacerlo
```bash
mkdir -p ~/evidencia
uptime; nproc
top -b -n1 | tee ~/evidencia/top.txt | head -15
ps aux --sort=-%cpu | head -5
```
- `uptime` da la **carga media** (*load average*) de 1, 5 y 15 minutos;
  `nproc`, cuántos núcleos hay. Una carga igual al número de núcleos es el
  100 %.
- `top -b -n1` es `top` en modo texto (`-b`, *batch*) con una sola pasada
  (`-n1`): una foto que se puede guardar. `tee` la guarda y la enseña a la vez.
- `ps aux --sort=-%cpu` ordena los procesos por CPU, de más a menos.

**Qué deberías ver:** un proceso de `www-data` al ~100 % de CPU. Apunta su PID.
:::

## Paso 2 · ¿Qué es en realidad?

**Pregúntate:** el nombre de un proceso lo elige el propio proceso. ¿Qué datos
no puede falsificar?

:::pista Cómo hacerlo
Los de `/proc/<PID>/`, que rellena el kernel. Como el proceso es de otro
usuario, hace falta `sudo`:
```bash
PID=<el número>
sudo ls -l /proc/$PID/exe
sudo tr '\0' ' ' < /proc/$PID/cmdline; echo
sudo tr '\0' '\n' < /proc/$PID/environ
sudo ss -tnp | grep "pid=$PID"
ps -o unit= -p $PID
```

| Fichero | Qué contiene |
|---|---|
| `/proc/PID/exe` | Enlace al binario que se está ejecutando. Si termina en `(deleted)`, el fichero se borró del disco, pero sigue en memoria. |
| `/proc/PID/cmdline` | La línea de comandos, con los argumentos separados por un carácter nulo (`tr` los convierte). |
| `/proc/PID/environ` | Sus variables de entorno, separadas igual. |

`ss -tnp` lista las conexiones TCP con su proceso; `ps -o unit=` dice qué
unidad de systemd lo lanza.

**Qué deberías ver:** un binario en `/tmp/.X11-cache/` marcado `(deleted)`, una
línea de comandos con `stratum+tcp://…:3333` (el protocolo de los pools de
minado), una variable `MINER_WALLET=` con la cartera y una unidad de systemd.
:::

## Paso 3 · Guarda la evidencia

**Pregúntate:** si el binario está borrado, ¿cómo lo copias?

:::pista Cómo hacerlo
Desde `/proc/<PID>/exe`, que sigue siendo legible mientras el proceso viva:
```bash
E=~/evidencia
sudo cp /proc/$PID/exe $E/binario
sudo chown $USER: $E/binario
sha256sum $E/binario > $E/sha256.txt
sudo ls -l /proc/$PID/exe > $E/exe.txt
sudo tr '\0' ' ' < /proc/$PID/cmdline > $E/cmdline.txt
sudo tr '\0' '\n' < /proc/$PID/environ > $E/environ.txt
sudo ss -tnp | grep "pid=$PID" > $E/conexiones.txt
ls -l $E
```
`sha256sum` calcula la huella del binario: sirve para buscarlo en bases de
datos de malware y demuestra después que la copia no cambió.
:::

## Paso 4 · Ahora sí, erradica

**Pregúntate:** si lo lanza una unidad con `Restart=always`, ¿qué pasa si
sólo haces `kill`?

:::pista Cómo hacerlo
Que systemd lo vuelve a lanzar. Para la unidad:
```bash
U=$(ps -o unit= -p $PID); echo "$U"
systemctl cat "$U"
sudo systemctl disable --now "$U"
sudo rm -rf /tmp/.X11-cache
bash /opt/lab/check.sh
```
`disable --now` lo para y quita su arranque automático. Guarda también una
copia de la unidad en la evidencia antes de borrarla, si vas a hacerlo.
:::

## Cómo actuar en una situación así

- **Orden de volatilidad:** memoria y conexiones antes que disco.
- Hash de todo lo que copies, y apunta hora y comando.
- Bloquea la IP del pool en el firewall y búscala en el resto de servidores:
  el minero suele ser la parte visible de un acceso que sigue abierto.

## Si te atascas

- **`cannot read symbolic link … Permission denied`:** falta `sudo`.
- **El check no encuentra el binario:** cópialo de `/proc/<PID>/exe`, no de
  `/tmp`: allí ya no está.
- **El proceso vuelve tras `kill`:** está gestionado por systemd; mira
  `ps -o unit=`.
