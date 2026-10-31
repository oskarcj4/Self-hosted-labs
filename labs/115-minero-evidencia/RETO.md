# Proceso minero: guardar evidencia antes de actuar

> Defensa del host · top · /proc · respuesta a incidentes

## Escenario

La CPU de `web-115` está al 100 % desde esta mañana (`~/ticket/INC-115.txt`).
Algo corre como `www-data` desde `/tmp`. El instinto es `kill -9` y a otra
cosa, pero entonces pierdes lo que forense necesita: qué binario era, contra
qué se conectaba, con qué parámetros y con qué cartera.

## Objetivos

1. Confirma la carga (`uptime`, `nproc`) e identifica el proceso (`top`, `ps`).
2. **Antes de detenerlo**, guarda en `~/evidencia/`:
   - una foto de `top` (`top -b -n1`),
   - una copia del binario (ojo: puede que ya no esté en disco),
   - su línea de comando y su entorno,
   - sus conexiones de red,
   - un `.txt` con el SHA-256 del binario.
3. Detén el proceso y retira su directorio de trabajo.

## Comandos que te pueden servir

```bash
uptime ; nproc
top            # P ordena por CPU, M por memoria, q sale
top -b -n1 > ~/evidencia/top.txt
ps aux --sort=-%cpu | head
sudo ls -l /proc/<PID>/exe ; sudo cp /proc/<PID>/exe ~/evidencia/binario
sudo cat /proc/<PID>/cmdline | tr '\0' ' '
sudo cat /proc/<PID>/environ | tr '\0' '\n'
sudo ss -tnp
sha256sum ~/evidencia/binario
ps -o unit= -p <PID>
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
