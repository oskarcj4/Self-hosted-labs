# Resolución guiada · Lab 121

:::piensa Tira del hilo
Un servidor web **recibe** conexiones. Que **inicie** una hacia fuera, a un
puerto raro, y la mantenga abierta es una mala señal. Tira del hilo con una
herramienta en cada salto: conexión → proceso → binario → quién lo arranca. Si
sólo matas el proceso, lo que lo arranca lo vuelve a lanzar.
:::

**El plan:** (1) encontrar la conexión, (2) llegar al proceso y a quien lo
arranca, (3) guardar evidencia y documentar, y (4) cortar y erradicar.

## Paso 1 · ¿A dónde habla el servidor?

:::pista Cómo hacerlo
```bash
sudo ss -tnp state established
```

| Opción | Qué hace |
|---|---|
| `-t` | Sólo TCP. |
| `-n` | Números en vez de nombres (IP y puertos sin resolver: más rápido y no te engaña un DNS). |
| `-p` | El proceso dueño de cada conexión (necesita `sudo`). |
| `state established` | Sólo conexiones abiertas. |

**Qué deberías ver:** una conexión hacia `198.51.100.66:6667`, con
`users:(("…",pid=NNNN,…))`. El 6667 es IRC, un canal clásico de mando y
control (C2): el malware espera órdenes por ahí.
:::

## Paso 2 · ¿Qué es y quién lo arranca?

:::pista Cómo hacerlo
Con el PID que viste:
```bash
PID=<el número>
sudo readlink /proc/$PID/exe
sudo cat /proc/$PID/cmdline | tr '\0' ' '; echo
ps -o pid,ppid,unit,cmd -p $PID
```
- `/proc/<PID>/exe` es un enlace al binario **real** que se está ejecutando,
  aunque el proceso se haga llamar de otra forma o el fichero se haya borrado.
- `/proc/<PID>/cmdline` es la línea de comandos; los argumentos van
  separados por un carácter nulo, y `tr` los cambia por espacios.
- `ps -o unit=` dice a qué unidad de systemd pertenece el proceso.

Mira la unidad:
```bash
systemctl cat <unidad>
```
**Qué deberías ver:** un binario escondido en `/var/tmp/.dbus/`, lanzado por
una unidad con nombre de servicio del sistema y `Restart=always`. Por eso, si
lo matas, vuelve.
:::

## Paso 3 · Evidencia y documentación

:::pista Cómo hacerlo
```bash
sudo mkdir -p /root/evidencia
sudo cp /proc/$PID/exe /root/evidencia/dbus-sync.bin
sudo cp /etc/systemd/system/<unidad> /root/evidencia/
nano ~/conexion.txt
```
Copiar desde `/proc/<PID>/exe` recupera el binario aunque ya lo hubieran
borrado del disco. En `~/conexion.txt` anota la IP y el puerto de destino, el
PID, la ruta del binario y el nombre de la unidad.
:::

## Paso 4 · Corta y erradica

**Pregúntate:** si otro servidor está igual de infectado, ¿qué bloqueo te
protege mientras investigas?

:::pista Cómo hacerlo
```bash
sudo iptables -I OUTPUT -d 198.51.100.66 -j REJECT
sudo systemctl disable --now <unidad>
sudo rm -f /etc/systemd/system/<unidad>
sudo systemctl daemon-reload
sudo rm -rf /var/tmp/.dbus
sudo ss -tnp state established
bash /opt/lab/check.sh
```
- `iptables -I OUTPUT -d <IP> -j REJECT`: inserta al principio de la cadena de
  **salida** una regla que rechaza todo lo que vaya a esa IP. Así ni este
  proceso ni otro que siga escondido puede volver a hablar con el C2.
- `disable --now`: para la unidad y quita su arranque automático.
- `daemon-reload`: systemd olvida la unidad borrada.

**Qué deberías ver:** la conexión ya no aparece.
:::

## Cómo actuar en una situación así

- Contén la salida (firewall) antes o a la vez que matas el proceso: el C2
  puede tener orden de borrar huellas en cuanto se corte.
- En servidores, filtrado de salida por defecto: casi nunca necesitan hablar
  con cualquier IP de Internet.
- Busca la IP del C2 en los logs del firewall y del proxy del resto de la red.

## Si te atascas

- **`ss` no muestra el proceso:** falta `sudo`.
- **Hay muchas conexiones:** filtra por puerto,
  `sudo ss -tnp state established '( dport = :6667 )'`.
- **El proceso vuelve:** borraste el binario pero no la unidad, o falta el
  `disable`.
