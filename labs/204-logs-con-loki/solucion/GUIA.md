# Resolución guiada · Lab 204

:::piensa ¿Qué es un stream en Loki?
Loki sólo indexa las etiquetas. Cada combinación distinta de etiquetas es un
stream con sus propios chunks. Con `ip` o `pedido` como etiqueta, cada
cliente o pedido crea un stream: millones de streams diminutos y un índice
enorme. El contenido de la línea no se indexa, pero se filtra rápido al
consultar (`|= "texto"`, `| json | campo > 10`).
:::

## Paso 1 · ¿Por qué no llega pagos?

:::pista Dónde mirar
`__path__` apunta a `/var/log/tienda/pagos/*.log`, pero el fichero es
`/var/log/tienda/pagos.log`. `curl -s localhost:9080/targets` también
muestra qué ficheros vigila Promtail.
:::

## Paso 2 · Tarjetas

:::pista Cómo
La etapa `replace` sustituye lo que capture el grupo de la expresión regular:
```yaml
- replace:
    expression: 'tarjeta=(\d{8,15})\d{4}\b'
    replace: '****'
```
Ponla antes de cualquier otra etapa. Lo que no sale de la máquina no hay que
borrarlo después.
:::

## Paso 3 · Etiquetas

:::pista Cómo
En pagos, extrae sólo `nivel` del JSON y pásalo a `labels`. En el catálogo,
quita `ip` del bloque `labels`. Comprueba con
`logcli series '{}' --since=1m --analyze-labels` que ninguna etiqueta tiene
cientos de valores.
:::

## Paso 4 · Trazas

:::pista Cómo
```yaml
- multiline:
    firstline: '^\d{4}-\d{2}-\d{2} '
    max_wait_time: 3s
```
Toda línea que no empiece por fecha se pega a la entrada anterior. Va antes
del `regex` que saca el nivel.
:::

## Paso 5 · Consultas

:::pista Cómo
- Pagos lentos: `{app="pagos"} | json | duration_ms > 1000`
- Errores por app: `sum by (app) (count_over_time({app=~".+", nivel="error"}[1m]))`

Si el catálogo usa `ERROR` y pagos `error`, normaliza con una etapa
`template` (`{{ ToLower .Value }}`) o usa `nivel=~"(?i)error"`.
:::
