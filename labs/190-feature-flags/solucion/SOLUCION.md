# Solución — Feature flags

## `flags.activo(flag, usuario)`

```python
f = _cargar().get(flag)                       # recarga si cambió el fichero (≤ 1 vez/s)
if not isinstance(f, dict) or f.get("activo") is not True:
    return False                              # interruptor de emergencia
if usuario in (f.get("usuarios") or []):
    return True
return cubeta(flag, usuario) < float(f.get("porcentaje", 0))
```

`flags.py` y `app.py` completos están en `solve.sh`.

## Antes y después

| | Variables de entorno | flags.json |
|-|----------------------|------------|
| Cambiar | editar la unidad + reiniciar | editar el fichero; ≤ 1 s |
| 20 % | `random()` por petición | hash estable por usuario |
| Subir el % | otra vez al azar | sólo entran usuarios nuevos |
| Error en la configuración | el servicio no arranca | se mantiene la última buena |
| Probar en interno | imposible | lista `usuarios` |

## Por qué el hash y no `random`

El usuario tiene que ver siempre lo mismo (sesión, carrito, métricas
comparables). Con `cubeta < porcentaje`, el 20 % está dentro del 50 %:
nadie "pierde" la función al ampliar el despliegue.

## Más allá del lab

- OpenFeature: API estándar, con proveedores (flagd, Unleash, LaunchDarkly).
- flagd lee un fichero o un ConfigMap y lo sirve a todos los servicios.
- Métricas por variante: compara errores y conversión de "nuevo" y "clásico" antes de subir el porcentaje.
