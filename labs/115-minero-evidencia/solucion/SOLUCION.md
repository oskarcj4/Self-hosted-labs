# Solución — Minero: primero la evidencia, luego matar

## Qué pasaba

Un minero renombrado a `php-fpm` corría desde `/tmp/.X11-cache`, lanzado por
una unidad systemd con reinicio automático y conectado a un pool externo.

## Arreglo

```bash
E=~/evidencia; mkdir -p $E
uptime > $E/uptime.txt; nproc >> $E/uptime.txt
top -b -n1 > $E/top.txt
ps aux --sort=-%cpu | head -5 > $E/ps.txt
PID=$(ps -eo pid,%cpu --sort=-%cpu | awk 'NR==2{print $1}')
ls -l /proc/$PID/exe > $E/exe.txt
sudo cp /proc/$PID/exe $E/binario
tr '\0' ' ' < /proc/$PID/cmdline > $E/cmdline.txt
sudo tr '\0' '\n' < /proc/$PID/environ > $E/environ.txt
sudo ss -tnp | grep "pid=$PID" > $E/conexiones.txt
sha256sum $E/binario > $E/sha256.txt
sudo chown -R analista:analista $E

UNIT=$(ps -o unit= -p $PID)
sudo systemctl disable --now "$UNIT"
sudo rm -rf /tmp/.X11-cache
bash /opt/lab/check.sh
```

## Más allá del lab

- Para memoria completa: `gcore <PID>` o LiME (memoria del host entero).
- Monta `/tmp` con `noexec` y vigila CPU sostenida con alertas.
- El acceso inicial (cómo llegó el minero) es lo siguiente que hay que investigar.
