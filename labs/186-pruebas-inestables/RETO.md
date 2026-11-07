# Tests inestables (flaky)

> DevOps · CI · pytest · determinismo · fixtures · inyección de dependencias

## Escenario

La suite de `~/pedidos` pasa casi siempre. "Casi" es el problema: una de
cada pocas ejecuciones en CI sale roja, alguien le da a **re-run**, sale
verde y se fusiona. El equipo ha aprendido a no fiarse del rojo. El día que
el rojo sea un bug de verdad, también le darán a re-run.

Un test inestable casi nunca es mala suerte. Suele depender de algo que no
controla:

- **la hora** (`now()`, `today()`, zonas horarias, medianoche);
- **el orden** (estado global que un test deja y otro hereda);
- **el azar** (`random` sin semilla, o un test que comprueba algo que el
  código no garantiza);
- **el entorno** (puertos fijos, `sleep` "para que le dé tiempo").

## Objetivos

1. La suite pasa **siempre**: en cualquier orden, con cualquier semilla, a
   cualquier hora y zona horaria, y con el puerto 8765 ocupado.
2. Sin reintentos, sin `skip`/`xfail` y sin borrar ni renombrar tests.
3. La suite sigue detectando bugs: el check introduce 5 errores en el
   código y cada uno debe poner la suite en rojo.
4. Las reglas de negocio no cambian. Sí puedes añadir parámetros opcionales.

## Pistas

```bash
cd ~/pedidos
for i in $(seq 20); do python3 -m pytest -q -p no:cacheprovider | tail -1; done
TZ=Europe/Madrid faketime '@2026-03-10 00:30:00' python3 -m pytest -q
python3 -m pytest -q tests/test_carrito.py::test_anadir tests/test_carrito.py::test_carrito_empieza_vacio
```

- `monkeypatch` y las fixtures `autouse` aíslan el estado global.
- `random.Random(semilla)` como parámetro hace reproducible el azar.
- `HTTPServer(("127.0.0.1", 0), ...)` pide un puerto libre al sistema operativo.

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
