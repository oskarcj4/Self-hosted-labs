# Solución — Lab 06

## 1. Listar timers

```bash
systemctl list-timers --all
```

Verás `sys-health.timer` disparando `sys-health.service` cada minuto. No es del
sistema.

## 2. Ver qué ejecuta

```bash
systemctl cat sys-health.service
```

`ExecStart=/opt/lab/.beacon.sh`: el beacon del atacante.

## 3. Parar y deshabilitar

```bash
sudo systemctl disable --now sys-health.timer sys-health.service
```

## 4. Borrar las unidades y recargar

```bash
sudo rm -f /etc/systemd/system/sys-health.service \
           /etc/systemd/system/sys-health.timer
sudo systemctl daemon-reload
systemctl list-timers --all | grep sys-health || echo "sin rastro"
```

## Verifica

```bash
bash /opt/lab/check.sh
```

## Lecciones

- La persistencia moderna usa `systemd` (`.service` + `.timer`), no sólo cron.
  Audita `systemctl list-timers --all` y `systemctl list-unit-files`.
- `/etc/systemd/system` = puesto por un humano; `/lib/systemd/system` = del paquete.
- `disable --now` para y deshabilita; luego borra los archivos y `daemon-reload`.
