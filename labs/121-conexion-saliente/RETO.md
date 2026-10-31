# Conexiones salientes sospechosas

> Defensa del host · ss · lsof · /proc · systemd

## Escenario

El firewall perimetral avisa: `web-121` mantiene una conexión **ESTABLISHED**
hacia una IP que no es vuestra, en un puerto poco habitual
(`~/ticket/INC-121.txt`). Un servidor web recibe conexiones; que **inicie**
una hacia fuera y la mantenga abierta es mala señal.

## Objetivos

1. Encuentra la conexión, su PID y el binario real (`/proc/PID/exe`).
2. Averigua **qué lo arranca**: si sólo lo matas, vuelve.
3. Córtalo de forma definitiva: unidad parada, deshabilitada y retirada;
   binario fuera de su sitio (guárdalo como evidencia antes).
4. Bloquea la IP en **salida** con iptables.
5. Documenta en `~/conexion.txt`: IP, puerto, PID, ruta del binario y
   nombre de la unidad.

## Comandos que te pueden servir

```bash
sudo ss -tunap
sudo lsof -i -P -n
sudo ls -l /proc/<PID>/exe ; sudo cat /proc/<PID>/cmdline | tr '\0' ' '
ps -o pid,ppid,unit,cmd -p <PID> ; systemctl status <PID>
sudo systemctl disable --now <unidad>
sudo iptables -I OUTPUT -d <IP> -j REJECT ; sudo iptables -S OUTPUT
```

> Complementa al Lab 02 (beacon + cron): aquí la persistencia es systemd.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
