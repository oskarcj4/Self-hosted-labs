# Solución — Conexión saliente sospechosa

## Qué pasaba

Un binario en `/var/tmp/.dbus/` mantenía una conexión ESTABLISHED a
`198.51.100.66:6667` (C2 por IRC), lanzado por una unidad systemd con
`Restart=always` con nombre parecido a uno del sistema.

## Arreglo

```bash
sudo ss -tnp state established | grep 6667
PID=$(sudo ss -tnp state established | grep '198.51.100.66:6667' | grep -o 'pid=[0-9]*' | head -1 | cut -d= -f2)
sudo lsof -i -P -n -p "$PID"
EXE=$(sudo readlink /proc/$PID/exe); UNIT=$(ps -o unit= -p "$PID")
sudo mkdir -p /root/evidencia
sudo cp /proc/$PID/exe /root/evidencia/dbus-sync.bin
sudo cp /etc/systemd/system/$UNIT /root/evidencia/
printf 'Destino: 198.51.100.66:6667\nPID: %s binario: %s unidad: %s\n' "$PID" "$EXE" "$UNIT" > ~/conexion.txt

sudo iptables -I OUTPUT -d 198.51.100.66 -j REJECT
sudo systemctl disable --now "$UNIT"
sudo rm -f /etc/systemd/system/$UNIT && sudo systemctl daemon-reload
sudo rm -rf /var/tmp/.dbus
bash /opt/lab/check.sh
```

## Más allá del lab

- Haz persistente el bloqueo (`iptables-save`, nftables o el firewall perimetral).
- Busca otros mecanismos de persistencia (lab 123) antes de dar el caso por cerrado.
