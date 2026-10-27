# Resolución guiada · Healthcheck y autorrecuperación

:::piensa Antes de tocar nada
"Proceso vivo" ≠ "servicio funcionando". `catalog` se cuelga sin morir, así que
`Restart=on-failure` no lo ve. La solución es un **watchdog** que compruebe lo
que ve el cliente (`/health`) y reinicie si no responde. La trampa número uno:
sin `--max-time`, tu `curl` se cuelga con el servicio y el watchdog nunca
reacciona.
:::

## Paso 1 · Reproduce el cuelgue

```bash
sudo touch /run/catalog/hang
systemctl is-active catalog                                 # active (systemd no ve nada)
curl -s --max-time 3 http://127.0.0.1:8300/health; echo "exit=$?"   # exit=28 timeout
```

## Paso 2 · El script del watchdog

**Pregúntate:** ¿qué necesita? timeout en el curl, tratar 500 como fallo,
reiniciar, avisar, y funcionar con el `PATH` de cron/timer.

:::pista `/usr/local/bin/catalog-watchdog.sh`
```bash
sudo tee /usr/local/bin/catalog-watchdog.sh >/dev/null <<'EOF'
#!/bin/bash
set -u
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
URL=http://127.0.0.1:8300/health
curl -fs --max-time 3 -o /dev/null "$URL" && exit 0
logger -t catalog-watchdog "catalog no responde; reiniciando"
systemctl restart catalog
curl -s --max-time 5 -X POST \
  --data "catalog: /health sin respuesta en 3 s; reiniciado por el watchdog ($(hostname) $(date '+%F %T'))" \
  http://127.0.0.1:9000/alert >/dev/null || logger -t catalog-watchdog "fallo al enviar alerta"
EOF
sudo chmod 755 /usr/local/bin/catalog-watchdog.sh
```
- `--max-time 3`: imprescindible; sin él el watchdog se cuelga igual que catalog.
- `-f`: un 500 cuenta como fallo, no sólo el timeout.
- La alerta va **después** del reinicio; si falla, queda en el journal.
:::

## Paso 3 · El timer (cada ≤30 s, también tras reinicio)

**Pregúntate:** ¿timer o cron? El timer da resolución de segundos, no solapa
ejecuciones y manda la salida al journal.

:::pista Cómo hacerlo
```bash
sudo tee /etc/systemd/system/catalog-watchdog.service >/dev/null <<'EOF'
[Unit]
Description=Watchdog de catalog
[Service]
Type=oneshot
ExecStart=/usr/local/bin/catalog-watchdog.sh
TimeoutStartSec=60
EOF
sudo tee /etc/systemd/system/catalog-watchdog.timer >/dev/null <<'EOF'
[Unit]
Description=Lanza el watchdog cada 15 s
[Timer]
OnBootSec=30s
OnUnitActiveSec=15s
AccuracySec=1s
[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now catalog-watchdog.timer
systemctl list-timers catalog-watchdog.timer
```
:::

## Paso 4 · Pruébalo

```bash
sudo touch /run/catalog/hang
watch -n1 'systemctl show catalog -p MainPID; curl -s --max-time 1 http://127.0.0.1:8300/health'
sudo tail /var/log/alerts/alerts.log
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Monitoriza desde fuera** (lo que ve el cliente), no sólo que el proceso exista.
- **Todo healthcheck lleva timeout.**
- En producción: exige **N fallos seguidos** antes de reiniciar (evita reacción
  a un pico) y limita reinicios por hora (evita bucles).
- systemd trae `WatchdogSec=` + `sd_notify WATCHDOG=1` si la app colabora.
- Un watchdog es una tirita: el bug del deadlock sigue abierto.

## Si te atascas

- El watchdog nunca actúa → falta `--max-time` en el curl, o el timer no está
  `enable --now`.
- Reinicia pero no llega la alerta → revisa el `POST` a `:9000/alert` y
  `journalctl -u catalog-watchdog`.
