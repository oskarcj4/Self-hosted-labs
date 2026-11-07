# Resolución guiada · Lab 185

:::piensa ¿Quién lee estos logs?
No una persona con `tail`: un agregador (Loki, Elasticsearch, CloudWatch) que
indexa campos, y una persona que a las 3 de la mañana busca
`request_id="..."`. El formato tiene que servir a los dos.
:::

## Paso 1 · Un formateador JSON

:::pista Cómo hacerlo
Una subclase de `logging.Formatter` cuyo `format()` devuelve `json.dumps`
de un dict con `ts`, `level`, `logger` y `msg`. Si `record.exc_info` existe,
`traceback.format_exception(*record.exc_info)` va en `exc`: los saltos de
línea quedan dentro del string JSON.
:::

## Paso 2 · El request_id

:::pista Cómo hacerlo
Un `contextvars.ContextVar`. Al empezar cada petición, `set()` con la
cabecera `X-Request-ID` o con `uuid4().hex`. El formateador lo añade a cada
línea. Devuélvelo con `send_header("X-Request-ID", ...)`.
:::

## Paso 3 · La línea de acceso

:::pista Cómo hacerlo
Envuelve `do_GET`/`do_POST`: mide con `time.perf_counter()` y, en un
`finally`, registra method, path (sin query), status y duration_ms. Anula
`log_message` para no duplicar.
:::

## Paso 4 · Lo que no debe salir

:::pista Qué hacer
- No registres las cabeceras ni el cuerpo enteros.
- Lo que sí registres, enmascarado: `****1111` y `m***@ejemplo.com`.
- Una función `enmascarar()` en el formateador hace de red de seguridad para
  todo lo demás.
:::

## Cómo actuar en una situación así

- Si un secreto llegó a los logs, **rótalo**: borrar el log no basta (puede estar en copias y en el agregador).
- Pasa el request_id a los servicios a los que llamas: así se sigue la petición entre servicios (como `traceparent` en el lab 170).
- Logs para eventos; métricas para contar (lab 171). No calcules tasas de error con grep.
