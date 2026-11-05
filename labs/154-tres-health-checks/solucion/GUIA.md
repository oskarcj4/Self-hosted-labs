# Resolución guiada · Lab 154

:::piensa Cada sonda, un trabajo
liveness = ¿vivo? (reinicia si no). readiness = ¿listo ahora? (corta tráfico si
no). startup = ¿ya arrancó? La trampa: no mezclar dependencias en liveness.
:::

## Paso 1 · liveness y startup

:::pista Cómo hacerlo
```python
# /livez
self._send(200, {"live": True})
# /startup : STARTED lo pone True un hilo tras el warmup
self._send(200 if STARTED else 503, {"started": STARTED})
```
:::

## Paso 2 · readiness con dependencia

:::pista Cómo hacerlo
```python
def db_ok():
    try:
        with socket.create_connection(("127.0.0.1",5432), timeout=0.5): return True
    except OSError: return False
# /readyz
ready = STARTED and db_ok()
self._send(200 if ready else 503, {"ready": ready})
```
:::

## Paso 3 · Probar la distinción

:::pista Cómo comprobarlo
```bash
sudo systemctl restart allsafe-api
sudo systemctl stop allsafe-db
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/readyz   # 503
curl -s -o /dev/null -w '%{http_code}\n' localhost:8080/livez    # 200
sudo systemctl start allsafe-db
```
:::

## Cómo actuar en una situación así

- liveness nunca depende de servicios externos. readiness sí.
- startup evita que un arranque lento dispare reinicios falsos.

## Si te atascas

- `readyz` da 200 sin base de datos: no estás comprobando la conexión real.
- `livez` da 503 al parar la base de datos: quitaste la dependencia de la sonda
  equivocada; liveness no debe mirar la base de datos.
