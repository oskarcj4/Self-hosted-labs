# Resolución guiada · Lab 121

:::piensa Antes de tocar nada
Una conexión ESTABLISHED a un puerto raro es un hilo. Tira de él: socket →
proceso → binario → quién lo arranca. Cada salto con una herramienta distinta.
:::

## Paso 1 · ¿A dónde habla el servidor?

**Pregúntate:** ¿qué conexiones salientes son normales aquí y cuál no lo es?

:::pista Cómo comprobarlo
```bash
sudo ss -tnp state established
```
El 6667 es IRC: un canal clásico de mando y control (C2).
:::

## Paso 2 · ¿Qué proceso es?

:::pista Cómo comprobarlo
```bash
sudo lsof -i -P -n -p <PID>
sudo readlink /proc/<PID>/exe
ps -o unit= -p <PID>
systemctl cat <unidad>
```
`Restart=always` explica por qué vuelve al matarlo.
:::

## Paso 3 · Evidencia y documentación

:::pista Qué guardar
```bash
sudo mkdir -p /root/evidencia
sudo cp /proc/<PID>/exe /root/evidencia/dbus-sync.bin
sudo cp /etc/systemd/system/<unidad> /root/evidencia/
nano ~/conexion.txt    # destino, PID, binario, unidad
```
:::

## Paso 4 · Corta y erradica

**Pregúntate:** si otro servidor está igual de infectado, ¿qué bloqueo te protege mientras investigas?

:::pista Cómo hacerlo
```bash
sudo iptables -I OUTPUT -d 198.51.100.66 -j REJECT
sudo systemctl disable --now <unidad>
sudo rm -f /etc/systemd/system/<unidad>; sudo systemctl daemon-reload
sudo rm -rf /var/tmp/.dbus
```
:::

## Cómo actuar en una situación así

- **Contén la salida** (firewall) antes o a la vez que matas: el C2 puede tener orden de borrar huellas.
- **Filtrado de salida por defecto** en servidores: casi nunca necesitan hablar con cualquier IP.
- Busca la IP del C2 en los logs de firewall/proxy del resto de la red.

## Si te atascas

- `ss` no muestra el proceso: falta `sudo`.
- Hay muchas conexiones: filtra por puerto, `ss -tnp state established '( dport = :6667 )'`.
