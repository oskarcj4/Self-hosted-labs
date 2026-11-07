# Resolución guiada · Lab 179

:::piensa ¿Para qué un catálogo?
Cuando suena la alerta de `postgres-pagos` a las 3 de la mañana, alguien
necesita saber en segundos quién es el dueño y qué servicios dependen de él.
Eso sólo funciona si el catálogo es correcto, y por eso se valida en CI.
:::

## Paso 1 · Leer los errores

:::pista Qué mirar
`catalogo validar .` da 6 errores en 3 ficheros. Hay dos tipos:
- **formato**: `apiVersion` y `metadata.name` (sin espacios ni mayúsculas raras);
- **referencias rotas**: owner, API y recurso que nadie ha declarado.
:::

## Paso 2 · Formato

:::pista Cómo hacerlo
`apiVersion: backstage.io/v1alpha1` y `name: catalogo-productos`.
:::

## Paso 3 · Lo que falta

:::pista Cómo hacerlo
- Un `Group` `equipo-logistica` con `parent: ingenieria`, y añádelo a los
  `children` de `ingenieria`.
- Un `API` `pagos-api` con `definition: {$text: ./openapi.yaml}`.
- Un `Resource` `postgres-pagos` con `type: database`.

Puedes ponerlos en el mismo `catalog-info.yaml` de pagos, separados por `---`.
:::

## Paso 4 · Registrar notificaciones

:::pista Cómo hacerlo
`servicios/notificaciones/catalog-info.yaml` con la anotación
`backstage.io/techdocs-ref: dir:.`, un `mkdocs.yml` y `docs/index.md`. Después
añade su ruta a `targets` en el `catalog-info.yaml` raíz. Si se te olvida, el
validador avisa de que nadie lo registra.
:::

## Cómo actuar en una situación así

- El descriptor vive con el código: quien cambia el servicio actualiza su ficha.
- Valida el catálogo en el pipeline de cada repo: un owner inexistente no se fusiona.
- Owners siempre equipos, no personas: las personas cambian de equipo.
