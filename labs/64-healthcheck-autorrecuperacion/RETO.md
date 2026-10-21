# Healthcheck y autorrecuperación

> Operaciones · systemd timers · watchdog · alertas

## Escenario

`catalog` en `cat-01` se queda colgado de vez en cuando: el proceso sigue
vivo, `systemctl status` dice `active (running)`, pero no responde. Como no
muere, `Restart=on-failure` no hace nada. La última vez lo detectaron los
clientes, 40 minutos tarde. Lee `~/ticket/PROB-6404.txt`.

Mientras desarrollo busca el bug, te toca poner un **watchdog**.

## Objetivos

1. `/usr/local/bin/catalog-watchdog.sh`:
   - comprueba `http://127.0.0.1:8300/health` esperando **3 s como mucho**,
   - si no responde: reinicia `catalog` y manda un `POST` a
     `http://127.0.0.1:9000/alert` con un texto que mencione `catalog`,
   - si responde: no hace nada.
2. Se ejecuta **cada 30 s como mucho**, también tras un reinicio de la
   máquina. Un timer de systemd es lo más cómodo; cron también vale.
3. Funciona con un entorno mínimo (`PATH=/usr/bin:/bin`).

El validador cuelga `catalog` de verdad y espera a que tu watchdog lo
recupere solo.

## Comandos que te pueden servir

```bash
curl -s --max-time 3 http://127.0.0.1:8300/health; echo "exit=$?"
sudo touch /run/catalog/hang          # simula el cuelgue (para tus pruebas)
curl -s http://127.0.0.1:9000/        # cómo usar el receptor de alertas
sudo tail -f /var/log/alerts/alerts.log
systemctl list-timers
man systemd.timer                     # OnBootSec=, OnUnitActiveSec=, AccuracySec=
journalctl -u catalog-watchdog -f
```

> Sin `--max-time`, `curl` espera para siempre... y tu watchdog se cuelga con
> `catalog`.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
