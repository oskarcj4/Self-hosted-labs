# Solución — Incidente completo

## Qué pasaba

```
deploy v3.4.1 (LOG_LEVEL=DEBUG)  ->  8 KB de log por petición
/var/log/pedidos (32 MB), sin rotación y con 3 logs viejos sin comprimir
volumen al 100 %  ->  OSError: No space left on device  ->  nginx 502
```

## Pasos

1. Comunicado: `HH:MM Investigando ...`.
2. `truncate -s 0 app.log` (no `rm`: la app lo tiene abierto) y `gzip` de los logs viejos.
3. `LOG_LEVEL=INFO` en la unidad, `daemon-reload`, `restart`.
4. `/etc/logrotate.d/pedidos` con `size`, `rotate`, `compress` y `copytruncate`.
   Opcional: cron horario, porque el logrotate de Debian corre una vez al día.
5. Comunicado: `HH:MM Resuelto ...`.
6. `postmortem.md` con las horas de `despliegues.log`, `journalctl` y `alerta.txt`.

## Por qué

- `rm` de un fichero abierto sólo quita el nombre: el inodo y sus bloques
  siguen ocupados hasta que el proceso lo cierra. `truncate` vacía el mismo inodo.
- `copytruncate` copia y vacía en sitio: sirve para apps que no saben reabrir
  su log. La alternativa es `create` + `postrotate` con una señal (USR1, HUP)
  o un reinicio.

## Más allá del lab

- Logs a stdout/journald (con `SystemMaxUse`) o a un agente: la app no gestiona ficheros.
- Alertas de saturación (disco, inodos) además de las de errores.
- Plantilla de postmortem compartida y una revisión semanal de las acciones abiertas.
