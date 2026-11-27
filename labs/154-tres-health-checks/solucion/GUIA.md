# Resolución guiada · Lab 154

:::piensa Tres preguntas distintas
Un orquestador (Kubernetes, un balanceador, systemd) le hace a tu app tres
preguntas diferentes, y cada respuesta provoca una acción distinta:

- **¿Estás vivo?** (*liveness*). Si dice que no, el orquestador lo **mata y
  reinicia**.
- **¿Puedes atender tráfico ahora?** (*readiness*). Si dice que no, deja de
  mandarle peticiones, pero **no lo mata**.
- **¿Has terminado de arrancar?** (*startup*). Mientras dice que no, las otras
  dos no se tienen en cuenta.

Un único `/health` que siempre dice "ok" contesta las tres igual, y mal.
:::

**El plan:** (1) ver el problema, (2) escribir las tres sondas,
(3) reiniciar y (4) demostrar la diferencia tirando la base de datos.

## Paso 1 · Ver el problema

**Objetivo:** comprobar que la app dice estar bien aunque su dependencia esté
caída.

:::pista Cómo hacerlo
```bash
sudo systemctl stop allsafe-db
curl -s -w '  (HTTP %{http_code})\n' localhost:8080/health
sudo systemctl start allsafe-db
```
`-w '… %{http_code}'` añade el código HTTP al final de la respuesta.

**Qué deberías ver:** `{"status": "ok"}  (HTTP 200)` con la base de datos
parada. Un balanceador le seguiría mandando tráfico que va a fallar.
:::

## Paso 2 · Las tres sondas

**Objetivo:** que cada ruta responda a su pregunta, y sólo a la suya.

**Pregúntate:** si la base de datos cae, ¿arregla algo reiniciar la app? ¿Cuál
de las tres sondas debe mirar la base de datos, entonces?

:::pista Cómo hacerlo
Reiniciar la app no arregla una base de datos caída: sólo provocaría que
**todas** las instancias se reinicien a la vez, en bucle. Por eso la base de
datos sólo la mira *readiness*. Sustituye `/opt/allsafe/app.py` entero (es
tuyo, no necesitas `sudo`):
```bash
nano /opt/allsafe/app.py
```
```python
import json, socket, threading, time
from http.server import BaseHTTPRequestHandler, HTTPServer

STARTED = False

def _warmup():
    global STARTED
    time.sleep(2)          # simula cargar cachés o abrir conexiones al arrancar
    STARTED = True

threading.Thread(target=_warmup, daemon=True).start()

def db_ok():
    try:
        with socket.create_connection(("127.0.0.1", 5432), timeout=0.5):
            return True
    except OSError:
        return False

class H(BaseHTTPRequestHandler):
    def _send(self, code, body):
        data = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/livez":
            self._send(200, {"live": True})
        elif self.path == "/startup":
            self._send(200 if STARTED else 503, {"started": STARTED})
        elif self.path == "/readyz":
            ready = STARTED and db_ok()
            self._send(200 if ready else 503, {"ready": ready})
        else:
            self._send(200, {"app": "allsafe-api"})

    def log_message(self, *a):
        pass

HTTPServer(("127.0.0.1", 8080), H).serve_forever()
```

| Pieza | Por qué es así |
|---|---|
| `/livez` → siempre 200 | Si el proceso puede contestar, está vivo. No mira nada más: así un corte de la base de datos no provoca reinicios. |
| `STARTED` y el hilo `_warmup` | Un hilo aparte espera 2 s y marca el arranque como terminado, sin bloquear el servidor. Mientras tanto `/startup` da `503`. |
| `db_ok()` | Intenta abrir una conexión TCP al puerto de la base de datos. `create_connection` lanza `OSError` si nadie escucha; lo capturamos y devolvemos `False`. |
| `timeout=0.5` | Si la base de datos está colgada (no caída), la sonda no se queda esperando. Una sonda lenta es casi tan mala como una que miente. |
| `/readyz` → `STARTED and db_ok()` | Lista para tráfico sólo si ya arrancó **y** su dependencia responde. Si no, `503`: "no me mandes nada ahora". |
| `503` | *Service Unavailable*: el código que entienden balanceadores y orquestadores como "temporalmente no disponible". |
:::

## Paso 3 · Reinicia la app

```bash
sudo systemctl restart allsafe-api
sleep 3
for r in livez startup readyz; do echo "$r: $(curl -s -o /dev/null -w '%{http_code}' localhost:8080/$r)"; done
```
El `sleep 3` deja pasar los 2 s de calentamiento. **Qué deberías ver:** las
tres en `200`. Si lanzas el bucle justo después del `restart`, verás
`startup: 503` y `readyz: 503`: es el calentamiento funcionando.

## Paso 4 · Demuestra la diferencia

```bash
sudo systemctl stop allsafe-db
for r in livez readyz; do echo "$r: $(curl -s -o /dev/null -w '%{http_code}' localhost:8080/$r)"; done
sudo systemctl start allsafe-db
sleep 1
curl -s -o /dev/null -w 'readyz: %{http_code}\n' localhost:8080/readyz
bash /opt/lab/check.sh
```
**Qué deberías ver:** con la base de datos parada, `livez: 200` y
`readyz: 503`. Al volver, `readyz: 200`, sin haber reiniciado la app.

## Cómo actuar en una situación así

- **liveness nunca depende de servicios externos.** readiness sí.
- En Kubernetes son `livenessProbe`, `readinessProbe` y `startupProbe`,
  apuntando a estas rutas. Mientras la `startupProbe` no pasa, las otras dos
  no se evalúan: así un arranque lento no provoca reinicios.
- `/readyz` puede comprobar varias dependencias (base de datos, caché, colas)
  y devolver el estado de cada una para diagnosticar.

## Si te atascas

- **`readyz` da 200 sin base de datos:** no estás comprobando la conexión
  real, o `db_ok()` captura la excepción y devuelve `True`.
- **`livez` da 503 al parar la base de datos:** pusiste la comprobación de la
  base de datos en la sonda equivocada.
- **Las tres dan error de conexión:** la app no arrancó. Mira el error con
  `journalctl -u allsafe-api -n 20 --no-pager` (suele ser la indentación).
