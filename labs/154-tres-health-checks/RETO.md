# Tres health checks

> Imagen y ejecución · liveness · readiness · startup · dependencias

## Escenario

`allsafe-api` (en `/opt/allsafe/app.py`) solo tiene `/health` y **siempre
devuelve 200**, incluso cuando su base de datos (`allsafe-db`, en
`127.0.0.1:5432`) está caída. El orquestador cree que la instancia está sana y
le manda tráfico que falla.

Las tres sondas tienen trabajos distintos:

- **liveness** (`/livez`): ¿el proceso está vivo? Si falla, el orquestador lo
  **reinicia**. No debe mirar dependencias (si no, un corte de base de datos
  reiniciaría procesos sanos en bucle).
- **readiness** (`/readyz`): ¿puede atender tráfico ahora? Mira dependencias. Si
  falla, el orquestador **deja de enviarle tráfico**, pero no lo mata.
- **startup** (`/startup`): ¿terminó el arranque? Protege a las otras dos
  durante un inicio lento.

## Objetivos

Implementa las tres rutas con su semántica:

1. `/livez` → 200 siempre que el proceso viva (sin mirar la base de datos).
2. `/startup` → 200 cuando terminó el calentamiento inicial.
3. `/readyz` → 200 solo si arrancó **y** la base de datos responde; si no, 503.

Comportamiento clave a demostrar: con la base de datos **caída**, `/readyz` da
503 pero `/livez` sigue en 200.

## Pistas

```bash
sudo systemctl restart allsafe-api
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/readyz
sudo systemctl stop allsafe-db     # readyz -> 503, livez -> 200
sudo systemctl start allsafe-db    # readyz -> 200
```

Conexión a la dependencia en Python:
```python
import socket
def db_ok():
    try:
        with socket.create_connection(("127.0.0.1",5432), timeout=0.5): return True
    except OSError: return False
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
