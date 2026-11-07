# Resolución guiada · Lab 186

:::piensa ¿Por qué no basta con reintentar?
Un reintento esconde el síntoma y deja la causa. La suite pierde su valor:
si el rojo "a veces es mentira", nadie investiga el rojo. Además, la
inestabilidad a veces es del **código**, no del test (una carrera real).
:::

## Paso 1 · Reproducir

:::pista Cómo hacerlo
Haz que el fallo salga siempre: lanza la suite en bucle, cambia el orden
(ejecuta un test suelto, o los tests de un fichero al revés) y mueve el reloj
con `faketime`. Hasta que no lo reproduces, no sabes si lo has arreglado.
:::

## Paso 2 · La hora

:::pista Qué pasa
`fecha_entrega()` usa la fecha UTC y el test usa `date.today()`, que es
local. Entre las 00:00 y la 01:00 (o las 02:00 en verano) en Madrid son días
distintos. Añade `ahora=None` a la función y pásale un reloj fijo en el test.
:::

## Paso 3 · El orden

:::pista Qué pasa
`CARRITO` es global: `test_anadir` lo deja con dos productos. Una fixture
`autouse` con `monkeypatch.setattr(pedidos, "CARRITO", [])` da a cada test
el suyo.
:::

## Paso 4 · El azar

:::pista Qué pasa
El test comprueba algo que la función **no** promete (que p1–p3 no van todos
al mismo repartidor): pasa en 9 de cada 10 barajados. Añade `rng=None` y
comprueba lo que sí garantiza: todos repartidos una vez y en partes iguales.
:::

## Paso 5 · El puerto y la carrera

:::pista Qué pasa
Dos fallos. El servidor se crea **dentro** del hilo, y el `sleep(0.1)` a veces
no basta. Y el 8765 puede estar ocupado. Crea el servidor en el test con el
puerto 0 (cuando vuelve, ya escucha) y lee el puerto de `server_address`.
:::

## Cómo actuar en una situación así

- Pon en cuarentena el test inestable con un ticket y un responsable. No dejes que el re-run se convierta en costumbre.
- Ejecuta en CI en orden aleatorio (`pytest-randomly`) y con la semilla impresa, para poder reproducir el fallo.
- Un fallo que "sólo pasa en CI" suele ser la hora, la zona horaria, el paralelismo o los recursos.
