# Solución — Tests inestables

## Causas y arreglos

| Test | Depende de | Arreglo |
|------|------------|---------|
| `test_fecha_entrega` | la hora: UTC en el código y local en el test | `fecha_entrega(ahora=None)`; el test pasa `datetime(2026, 3, 9, 23, 30, tzinfo=utc)` |
| `test_carrito_empieza_vacio` | el orden: `CARRITO` global | fixture `autouse` con `monkeypatch.setattr(pedidos, "CARRITO", [])` |
| `test_repartir` | el azar, y una propiedad que no está garantizada | `repartir(..., rng=None)`; se comprueba reparto completo, equilibrado y reproducible |
| `test_salud` | carrera (`sleep(0.1)`) y puerto fijo | `crear_servidor(0)` en la fixture; el puerto se lee de `server_address` |

El código completo está en `solve.sh`. En producción se sigue llamando a las
funciones igual que antes: los parámetros nuevos son opcionales.

## Cómo lo comprueba el check

- Orden normal, inverso y 6 barajados (un plugin de pytest en `/opt/lab/tests`).
- 30 semillas de `random` fijadas antes de cada test.
- `faketime` a las 00:30 y 01:30 en Madrid y a las 23:30 en México.
- Otro proceso en el puerto 8765.
- 5 mutaciones (entrega a 3 días, IVA, `anadir`, reparto, salud): cada una
  tiene que poner algún test en rojo. Un test que siempre pasa no sirve.

## Más allá del lab

- `freezegun` o `time-machine` para congelar el reloj en Python.
- `pytest-randomly` baraja y fija semillas; `pytest -n auto` (pytest-xdist) destapa estado compartido.
- Mutación de verdad: `mutmut` o `cosmic-ray` generan cientos de mutantes.
