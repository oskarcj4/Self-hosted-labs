# Solución — Logs para producción

## Antes y después

```
login de marta.lopez@ejemplo.com con contraseña Clave-42
```
```json
{"ts": "2026-11-06T10:42:13.120+00:00", "level": "INFO", "logger": "tienda", "msg": "login",
 "request_id": "chk-1", "usuario": "m***@ejemplo.com"}
{"ts": "2026-11-06T10:42:13.121+00:00", "level": "INFO", "logger": "tienda.acceso", "msg": "petición",
 "request_id": "chk-1", "method": "POST", "path": "/login", "status": 200, "duration_ms": 0.4}
```

## Piezas (app completa en `solve.sh`)

| Pieza | Qué hace |
|-------|----------|
| `JSONFormatter` | una línea JSON; `exc` con la traza; aplica `enmascarar()` |
| `ContextVar request_id` | un valor por petición, también con hilos |
| `_atender()` | fija el request_id, mide y registra la línea de acceso en `finally` |
| `enmascarar()` | tarjetas, emails y `bearer/password/token` |
| `LOG_LEVEL` | `logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))` |

## Por qué

- `contextvars` en lugar de una global: con `ThreadingHTTPServer` hay varias
  peticiones a la vez, y cada hilo ve su propio valor.
- Escribir a stdout y dejar que systemd/Docker lo recojan: la app no rota
  ficheros (lab 178) y el agente de logs lo lee del journal.

## Más allá del lab

- `python-json-logger` o `structlog` hacen esto sin código propio.
- En el agregador, indexa pocos campos (level, service, request_id). El resto, como texto.
- Muestreo: el 100 % de los errores y un % de los accesos cuando el volumen es alto.
