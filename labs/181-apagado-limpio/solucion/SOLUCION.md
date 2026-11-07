# Solución — Apagado limpio

## Cambios

| Fichero | Antes | Después |
|---------|-------|---------|
| `Dockerfile` | `CMD ./entrypoint.sh` | `CMD ["./entrypoint.sh"]` |
| `entrypoint.sh` | `python app.py` | `exec python app.py` |
| `app.py` | sin manejador | SIGTERM → `shutdown()` en otro hilo, `server_close()` espera las peticiones en curso, log y `exit(0)` |
| `compose.yaml` | — | `init: true` (tini) y `stop_grace_period: 20s` |

## La cadena, arreglada

```
docker stop -> SIGTERM -> tini (PID 1) -> python (manejador)
             -> deja de aceptar -> termina /lento -> "apagado limpio" -> exit 0
tini recoge los huérfanos de /tarea: no quedan zombis
```

## Por qué

- El kernel no aplica la acción por defecto de una señal a PID 1. Sin
  manejador, SIGTERM no hace nada.
- `exec` reemplaza el proceso del shell por el de Python: mismo PID y las
  señales llegan directas.
- PID 1 hereda los huérfanos. Si no hace `wait()`, se quedan como zombis y
  ocupan entradas de la tabla de procesos.

## Más allá del lab

- `STOPSIGNAL` en el Dockerfile si tu app espera otra señal (nginx: SIGQUIT).
- Kubernetes: `preStop` con un `sleep` corto para que el balanceador deje de
  mandar tráfico antes del SIGTERM.
- gunicorn y uvicorn ya hacen un apagado ordenado con SIGTERM.
