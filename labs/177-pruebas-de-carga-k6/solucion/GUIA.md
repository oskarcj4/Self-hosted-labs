# Resolución guiada · Lab 177

:::piensa Una prueba de carga es un experimento
Hipótesis ("aguanta 50 usuarios con p95 < 300 ms"), medida (k6 con umbrales)
y, si falla, ¿dónde? Cambia **una** cosa cada vez y vuelve a medir.
:::

## Paso 1 · La prueba

:::pista Qué escribir
Etapas que suban a 50 VUs y se mantengan, umbrales globales, y `tags` por ruta
para verlas por separado:
```javascript
http.get(url, { tags: { ruta: 'buscar' } });
// thresholds: { 'http_req_duration{ruta:buscar}': ['p(95)<300'] }
```
:::

## Paso 2 · El primer cuello

:::pista Qué mirar
Mientras corre la prueba: `top -H -p <pid>` muestra **un** hilo y la CPU casi
libre. La latencia de `/productos` (20 ms de espera) sube a segundos: las
peticiones hacen cola. `HTTPServer` atiende de una en una.
:::

:::pista Cómo hacerlo
`ThreadingHTTPServer` en lugar de `HTTPServer`, y reinicia el servicio.
:::

## Paso 3 · El segundo cuello

:::pista Qué mirar
Ahora `/productos` va bien, pero `/buscar` no, y la CPU está al 100 %.
`EXPLAIN QUERY PLAN` dice `SCAN productos`: lee 300 000 filas en cada búsqueda.
:::

:::pista Cómo hacerlo
```bash
sqlite3 ~/catalogo/catalogo.db "CREATE INDEX idx_productos_categoria ON productos(categoria)"
```
:::

## Cómo actuar en una situación así

- Prueba con la carga esperada **y** por encima (x2), con datos de tamaño real.
- Pon la prueba en el pipeline con umbrales: una regresión de rendimiento rompe el build.
- Mira saturación (CPU, hilos, conexiones) mientras corre: dice dónde está la cola.

## Si te atascas

- `k6 inspect prueba.js` valida el script sin lanzarlo.
- Si el check falla sólo en tu prueba, revisa que sus umbrales sean alcanzables.
