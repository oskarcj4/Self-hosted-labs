# Apagado limpio: SIGTERM, PID 1 y zombis

> DevOps · contenedores · señales · PID 1 · tini · graceful shutdown

## Escenario

En cada despliegue, quien estaba generando un informe recibe un error. Y
`docker compose stop` tarda **10 segundos** exactos y el contenedor sale con
**137**.

Cuando paras un contenedor, Docker manda **SIGTERM** al **PID 1** del
contenedor, espera (10 s por defecto) y después manda **SIGKILL**. Lo que
falla está en esa cadena:

- **Forma shell** (`CMD ./script`): el PID 1 es `/bin/sh`, no tu app.
- **Script sin `exec`**: bash se queda de PID 1 y no reenvía SIGTERM a su hijo.
- **PID 1 es especial**: el kernel ignora las señales para las que PID 1 no
  tiene manejador. Sin manejador de SIGTERM, la app no se entera.
- **Huérfanos**: los procesos huérfanos se cuelgan de PID 1. Si PID 1 no los
  recoge (`wait`), quedan **zombis**. Para eso existen `tini` y `--init`.

Docker corre **dentro** del lab: nada toca tu máquina.

## Objetivos

1. `docker compose stop` en menos de 5 s, con código de salida 0.
2. Una petición a `/lento` en curso durante la parada termina con 200.
3. La app escribe `apagado limpio` al salir.
4. Ningún zombi tras usar `/tarea`.
5. `CMD`/`ENTRYPOINT` en forma exec.

## Pistas

```bash
cd ~/app && docker compose up -d --build
docker compose exec app cat /proc/1/cmdline | tr '\0' ' '; echo   # ¿quién es PID 1?
curl localhost:8000/lento & sleep 0.5; time docker compose stop
docker compose ps -a
for i in $(seq 20); do curl -s localhost:8000/tarea; done; docker top "$(docker compose ps -q app)" -o pid,stat,comm
```

```python
import signal
signal.signal(signal.SIGTERM, manejador)   # y desde ahí: srv.shutdown() en otro hilo
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
