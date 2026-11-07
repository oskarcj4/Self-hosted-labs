# Resolución guiada · Lab 181

:::piensa ¿Por qué justo 10 segundos?
Son los 10 s de gracia de `docker stop`. Nadie atiende el SIGTERM, Docker
espera el plazo completo y manda SIGKILL (128 + 9 = 137). La petición en
curso muere con el proceso.
:::

## Paso 1 · ¿Quién es PID 1?

:::pista Qué mirar
`docker compose exec app cat /proc/1/cmdline | tr '\0' ' '` muestra
`/bin/sh -c ./entrypoint.sh` o `/bin/bash ./entrypoint.sh`. La app es un
hijo al que nadie reenvía la señal.
:::

:::pista Cómo hacerlo
`CMD ["./entrypoint.sh"]` y, dentro del script, `exec python app.py`: el
proceso de Python **sustituye** al shell.
:::

## Paso 2 · La app escucha SIGTERM

:::pista Cómo hacerlo
```python
srv = ThreadingHTTPServer(("0.0.0.0", 8000), H)
srv.daemon_threads = False         # server_close() espera a los hilos

def parar(signum, frame):
    threading.Thread(target=srv.shutdown).start()   # shutdown() no se puede llamar desde serve_forever

signal.signal(signal.SIGTERM, parar)
srv.serve_forever()
srv.server_close()
log("apagado limpio"); sys.exit(0)
```
:::

## Paso 3 · Los zombis

:::pista Qué mirar
Ahora Python es PID 1. Cada `/tarea` deja un `sleep` huérfano que, al
acabar, queda `<defunct>`: Python no hace `wait` de procesos que no son suyos.
:::

:::pista Cómo hacerlo
`init: true` en `compose.yaml` (o `docker run --init`): `tini` es PID 1,
reenvía las señales a tu app y recoge los huérfanos.
:::

## Cómo actuar en una situación así

- Forma exec siempre, y `exec` en los entrypoints.
- Manejar SIGTERM es parte de la app: dejar de aceptar, terminar, cerrar conexiones.
- En Kubernetes es igual: `terminationGracePeriodSeconds` (30 s) y, mientras tanto, el pod sale de los Endpoints.
