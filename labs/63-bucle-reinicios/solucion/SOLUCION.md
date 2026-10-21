# Solución — Bucle de reinicios

## 1. Primera causa: no encuentra su configuración

```bash
systemctl status payments-worker
#  Active: failed (Result: resources) ... start-limit-hit
sudo journalctl -u payments-worker -n 20 --no-pager
# payments-worker.service: Failed to load environment files: No such file or directory
# payments-worker.service: Failed with result 'resources'.
# payments-worker.service: Start request repeated too quickly.
ls /etc/payments/      # payments.env  token     (worker.env ya no existe)
```

Corrígelo con un drop-in, así no tocas la unit original:

```bash
sudo systemctl edit payments-worker
```

```ini
[Service]
EnvironmentFile=
EnvironmentFile=/etc/payments/payments.env
```

La línea vacía `EnvironmentFile=` **borra** el valor heredado. Sin ella,
systemd seguiría cargando también el fichero viejo y seguiría fallando.

```bash
sudo systemctl reset-failed payments-worker
sudo systemctl start payments-worker
```

## 2. Segunda causa: el puerto está ocupado

```bash
sudo journalctl -u payments-worker -n 5 --no-pager
# FATAL: no puedo escuchar en 127.0.0.1:9090: [Errno 98] Address already in use
sudo ss -ltnp 'sport = :9090'
# users:(("python3",pid=123,...))
systemctl status 123
# ● debug-9090.service - debug temporal (INC-5870) BORRAR
```

Un servidor de depuración lanzado con `systemd-run` hace dos semanas, todavía
vivo. Como es una unit transitoria, basta con pararla (no tiene fichero en
disco y no vuelve al reiniciar):

```bash
sudo systemctl stop debug-9090
sudo systemctl reset-failed payments-worker
sudo systemctl restart payments-worker
```

## 3. Verifica la estabilidad, no el instante

```bash
watch -n1 'systemctl show payments-worker -p ActiveState,NRestarts,MainPID'
curl -s http://127.0.0.1:9090/health
```

## Lecciones

- `Restart=always` + `RestartSec=1` esconden el problema. Mira `NRestarts`
  y el journal, no sólo `active`.
- `start-limit-hit`: systemd dejó de intentarlo. Arregla la causa, luego
  `reset-failed`, y después arranca.
- Los cambios a una unit van en un drop-in (`systemctl edit`). Para
  **reemplazar** una directiva que se puede repetir (`EnvironmentFile`,
  `ExecStart`), primero vacíala.
- `EnvironmentFile=-/ruta` (con `-`) hace el fichero opcional. Aquí sería un
  error: el servicio arrancaría sin configuración.
- "Address already in use" → `ss -ltnp` → `systemctl status PID` para saber
  quién es el dueño.
