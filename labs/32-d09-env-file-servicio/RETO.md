# Día 09 — Proteger el env file de un servicio

> 30 días de DevSecOps · Linux · Permisos e identidad de servicios

## Escenario

`notifier` envía alertas por SMTP y webhook. Sus secretos viven en
`/etc/notifier/notifier.env`, que systemd carga con `EnvironmentFile=`. El
fichero es legible por cualquier usuario del servidor y, además, alguien
dejó una copia `.bak` al lado "por si acaso".

## Objetivos

1. `notifier.env` sólo accesible para quien lo necesita: dueño `root`, nada
   para "otros", sin escritura de grupo.
2. Ningún fichero con esos secretos (copias incluidas) puede quedar legible
   para un usuario normal como `analista`.
3. El servicio debe seguir cargando sus secretos **desde el env file**
   (no los copies dentro de la unidad: `systemctl cat` es público).
4. `notifier` activo y sano: `curl http://127.0.0.1:8500/` →
   `smtp configured, webhook configured`.

> Pregunta clave: ¿quién lee realmente un `EnvironmentFile`, el servicio
> (`User=notifier`) o systemd?

## Comandos que te pueden servir

```bash
ls -la /etc/notifier/
systemctl cat notifier
systemctl show notifier -p User -p EnvironmentFiles
sudo grep -rl 'SMTP_PASSWORD' /etc /opt /home 2>/dev/null
sudo systemctl restart notifier && curl -s http://127.0.0.1:8500/
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
