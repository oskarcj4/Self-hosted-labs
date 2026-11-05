# Solución — Tres health checks

## Qué pasaba

Una sola sonda `/health` que devolvía 200 pasara lo que pasara. Con la base de
datos caída, el orquestador seguía enrutando tráfico a una instancia rota.

## Arreglo

Tres rutas con semántica distinta (ver `app.py`):

```python
STARTED = False           # lo pone True un hilo tras el warmup

def db_ok():
    try:
        with socket.create_connection(("127.0.0.1",5432), timeout=0.5): return True
    except OSError: return False

# /livez   -> 200 siempre (proceso vivo)
# /startup -> 200 si STARTED
# /readyz  -> 200 si STARTED and db_ok(), si no 503
```

`sudo systemctl restart allsafe-api` y a probar.

## Por qué importa la distinción

- Si **liveness** mirara la base de datos, un corte de red reiniciaría todos los
  pods sanos a la vez: tormenta de reinicios, peor que el corte original.
- **readiness** sí mira dependencias: saca el pod del balanceo mientras la base
  de datos no responde, y lo vuelve a meter cuando regresa. Sin reinicios.
- **startup** da aire a arranques lentos: hasta que no termina, liveness no
  empieza a contar fallos.

## Más allá del lab

- En Kubernetes esto son `livenessProbe`, `readinessProbe` y `startupProbe` en
  el manifiesto, apuntando a estas mismas rutas.
- `readyz` puede comprobar varias dependencias (base de datos, caché, colas) y
  devolver el detalle por dependencia para diagnóstico.
- Ajusta `initialDelaySeconds`/`periodSeconds` a la realidad del arranque.
