# Solución — Portal interno (catálogo de software)

## Errores y arreglos

| Error | Arreglo |
|-------|---------|
| `apiVersion: backstage.io/v1` | `backstage.io/v1alpha1` |
| `name: Catalogo de productos` | `catalogo-productos` |
| owner `equipo-logistica` no existe | `Group` nuevo con `parent: ingenieria` |
| `pagos-api` no existe | `API` con `type: openapi` y `definition: {$text: ./openapi.yaml}` |
| `resource:postgres-pagos` no existe | `Resource` con `type: database`, owner `equipo-pagos` |

## notificaciones

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: notificaciones
  annotations:
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: plataforma
  system: tienda
  dependsOn: [component:envios]
```

Más `mkdocs.yml`, `docs/index.md` y la línea en `targets` de la Location raíz.
Después, `git add -A && git commit`.

## Por qué

- El portal resuelve relaciones en los dos sentidos: `envios` muestra que
  `notificaciones` depende de él sin que nadie lo escriba en `envios`.
- Las referencias rotas son peores que no tener catálogo: dan respuestas falsas.

## Más allá del lab

- Backstage real: `catalog.locations` en `app-config.yaml`, o descubrimiento
  automático de `catalog-info.yaml` en todos los repos de la organización.
- Scaffolder (plantillas): crea un repo nuevo con su `catalog-info.yaml` ya
  correcto (lab 222, camino estándar).
- Scorecards: qué servicios no tienen owner, runbook o alertas.
