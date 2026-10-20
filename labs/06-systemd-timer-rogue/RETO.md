# Lab 06 — Persistencia con systemd: el "servicio de salud" que no lo es

## Escenario

`svc-prod-06` corre con `systemd` como init. Tras un incidente, sospechas que el
atacante dejó persistencia **moderna**: ya nadie usa sólo cron. Un `*.service` +
`*.timer` disfrazado de mantenimiento relanza su beacon cada minuto. Tienes que
encontrarlo, pararlo, deshabilitarlo y borrar las unidades.

## Objetivos

1. **Lista los timers activos** y encuentra el que no es del sistema.
2. **Identifica la unidad de servicio** que ese timer dispara y qué ejecuta.
3. **Párala y deshabilítala** (el timer y el servicio).
4. **Borra los archivos de unidad** y recarga systemd.

## Comandos que te pueden servir

```bash
systemctl list-timers --all
systemctl status sys-health.timer sys-health.service
systemctl cat sys-health.service        # ¿qué ExecStart tiene?
sudo systemctl disable --now sys-health.timer sys-health.service
sudo rm -f /etc/systemd/system/sys-health.service /etc/systemd/system/sys-health.timer
sudo systemctl daemon-reload
```

> Un servicio legítimo suele vivir en `/lib/systemd/system`. Los que aparecen en
> `/etc/systemd/system` fueron puestos por alguien: revisa esos primero.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
