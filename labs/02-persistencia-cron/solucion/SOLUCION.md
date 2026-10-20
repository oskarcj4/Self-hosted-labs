# Solución — Lab 02

El orden importa: **persistencia → proceso → binario**. Si matas el proceso
primero, cron lo revive en menos de un minuto.

## 1. Encontrar la conexión oculta

```bash
ss -tulpn | grep 4444
```

Verás algo como `LISTEN ... 0.0.0.0:4444 ... users:(("system-update",pid=XXX,...))`.
Ahí está tu PID y el nombre del proceso: `system-update` (suena oficial, pero no lo es).

## 2. Identificar al impostor

```bash
PID=$(pgrep -f /tmp/system-update)
ls -la /proc/$PID/exe
ls -la /tmp/system-update
```

El binario vive en `/tmp`. **Ningún servicio legítimo del sistema se ejecuta
desde `/tmp`** — es una carpeta de basura temporal, escribible por todos. Bandera roja.

## 3. Desarmar la persistencia PRIMERO

```bash
ls -la /etc/cron.d/
cat /etc/cron.d/system-maint
```

Hay una línea `* * * * * root /opt/lab/.respawn.sh` disfrazada de "mantenimiento".
Esa es la bomba de tiempo que resucita el beacon. Elimínala:

```bash
sudo rm -f /etc/cron.d/system-maint
```

(En un caso real revisa también `crontab -l`, `/etc/crontab`, `/etc/cron.*/`,
y servicios systemd/`.timer`.)

## 4. Matar el proceso y borrar el binario

```bash
sudo kill -9 "$PID"
sudo rm -f /tmp/system-update
```

## 5. Confirmar que no vuelve

```bash
sleep 65
ss -tulpn | grep 4444 || echo "puerto 4444 cerrado"
pgrep -f /tmp/system-update || echo "proceso no vuelve"
bash /opt/lab/check.sh
```

## Lecciones

- `ss -tulpn` (o `netstat -tulpn`) revela el puerto **y** el proceso dueño; el panel
  de monitoreo puede estar manipulado, pero el kernel no miente.
- Ruta de ejecución (`/proc/PID/exe`) > nombre del proceso. Los nombres se falsifican.
- Erradicar persistencia antes de matar procesos; si no, juegas al whack-a-mole.
- Cierra el puerto en el firewall además de matar el proceso
  (`sudo iptables -A INPUT -p tcp --dport 4444 -j DROP`).
