# Solución — Healthcheck y autorrecuperación

## 1. Reproduce el fallo

```bash
sudo touch /run/catalog/hang
systemctl is-active catalog                       # active  <- systemd no ve nada raro
curl -s --max-time 3 http://127.0.0.1:8300/health; echo "exit=$?"   # exit=28 (timeout)
sudo systemctl restart catalog                    # el arreglo manual de siempre
```

"El proceso está vivo" y "el servicio funciona" no son lo mismo. Hay que
comprobar lo que ve el cliente.

## 2. El script

```bash
sudo tee /usr/local/bin/catalog-watchdog.sh >/dev/null <<'EOF'
#!/bin/bash
# Watchdog de catalog: si /health no responde en 3 s, reinicia y avisa.
set -u
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
URL=http://127.0.0.1:8300/health

if curl -fs --max-time 3 -o /dev/null "$URL"; then
  exit 0
fi
logger -t catalog-watchdog "catalog no responde en $URL; reiniciando"
systemctl restart catalog
curl -s --max-time 5 -X POST \
     --data "catalog: /health sin respuesta en 3 s; catalog reiniciado por el watchdog ($(hostname) $(date '+%F %T'))" \
     http://127.0.0.1:9000/alert >/dev/null || logger -t catalog-watchdog "no pude enviar la alerta"
EOF
sudo chmod 755 /usr/local/bin/catalog-watchdog.sh
```

- `--max-time 3`: **imprescindible**. Si no lo pones, `curl` se queda
  esperando con el servicio colgado y el watchdog nunca reacciona.
- `-f`: un 500 también cuenta como fallo, no sólo el timeout.
- La alerta va **después** del reinicio, y si el envío falla queda en el
  journal (`logger`).

## 3. El timer

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
Description=Lanza el watchdog de catalog cada 15 s

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

Un timer tiene ventajas frente a cron: resolución de segundos, no lanza una
ejecución nueva mientras la anterior sigue en marcha, y la salida va al
journal (`journalctl -u catalog-watchdog`).

## 4. Pruébalo

```bash
sudo touch /run/catalog/hang
watch -n1 'systemctl show catalog -p MainPID; curl -s --max-time 1 http://127.0.0.1:8300/health'
sudo tail /var/log/alerts/alerts.log
```

## Lecciones

- Monitoriza **desde fuera** (lo que ve el cliente), no sólo que el proceso
  exista.
- Todo healthcheck lleva timeout.
- En producción conviene exigir N fallos seguidos antes de reiniciar (evita
  reinicios por un pico puntual) y limitar los reinicios por hora (evita un
  bucle de reinicios).
- systemd tiene su propio mecanismo: `WatchdogSec=` con `sd_notify
  WATCHDOG=1`. Requiere que la app colabore, pero no necesita script.
- Un watchdog es una tirita. El ticket del deadlock sigue abierto.
