# Logs para producción

> SRE · logging estructurado · JSON · request_id · niveles · datos sensibles

## Escenario

Los logs de la tienda se escribieron para el portátil de quien la programó:

```
DEBUG cabeceras: {'Authorization': 'Bearer sk_live_...', ...}
login de ana@ejemplo.com con contraseña secreta
Traceback (most recent call last):
  File "app.py", line 34, in do_GET
ZeroDivisionError: division by zero
```

En producción eso es un problema:

- **Texto libre**: no se puede filtrar por campos (`status=500`, `path=/pagar`).
- **Trazas de varias líneas**: cada línea llega suelta al agregador de logs.
- **Sin request_id**: con 200 peticiones por segundo, no sabes qué líneas son
  de la misma petición.
- **DEBUG siempre activo**: ruido y coste.
- **Secretos y datos personales**: un token en un log es un token filtrado.
  Un email o una tarjeta, un problema de RGPD y de PCI DSS.

## Objetivos

1. Cada línea es **un objeto JSON** con `ts`, `level` y `msg`.
2. Una línea de acceso por petición: `method`, `path`, `status`, `duration_ms`.
3. `request_id` en todas las líneas de la petición. Se toma de `X-Request-ID`
   o se genera, y se devuelve en la respuesta.
4. Un error es **una** línea `ERROR` con la traza en `exc`.
5. Nivel desde `LOG_LEVEL` (INFO por defecto).
6. Ni contraseñas, ni tokens, ni tarjetas, ni emails completos.

## Pistas

```bash
journalctl -u tienda -f -o cat
curl -H 'X-Request-ID: prueba-1' localhost:8080/productos -i
```

```python
import logging, contextvars
class JSONFormatter(logging.Formatter):
    def format(self, record): ...        # json.dumps({...}); record.exc_info para la traza
request_id = contextvars.ContextVar("request_id", default=None)   # uno por petición (por hilo)
log.info("cobro", extra={"campos": {...}})
log.exception("algo falló")             # ERROR + exc_info
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
