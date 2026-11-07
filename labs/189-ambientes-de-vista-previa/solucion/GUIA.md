# Resolución guiada · Lab 189

:::piensa ¿Qué hace que algo sea "efímero"?
Que se crea y se destruye entero, solo y sin dejar nada. Para eso todo lo
del PR tiene que llevar su nombre: proyecto, imagen, volumen, puerto y
directorio.
:::

## Paso 1 · Un nombre por PR

:::pista Cómo hacerlo
`docker compose -p pr-N` separa contenedores, red y volúmenes
(`pr-N_datos`). La imagen es `tienda:pr-N`. El puerto es `9000+N`, pasado
como variable al compose (`${PREVIEW_PORT:?}`).
:::

## Paso 2 · La rama sin checkout

:::pista Cómo hacerlo
`git archive pr-N | tar -x -C ~/.previews/pr-N` exporta la rama a otro
directorio y construye desde ahí. El compose de las vistas previas vive en
`ci/` (en `main`), no en cada rama.
:::

## Paso 3 · Los datos

:::pista Qué pasa
La app siembra la base de datos con `datos/semilla.sql` si el volumen está
vacío. Basta con no copiar nada de `/srv/prod`. Borra también el volumen
viejo `tienda_datos`: tiene datos reales.
:::

## Paso 4 · Limpiar

:::pista Cómo hacerlo
`down -v --remove-orphans`, `docker image rm tienda:pr-N` y borrar el
directorio. Para `gc`, saca los proyectos `pr-*` de las etiquetas
`com.docker.compose.project` de contenedores **y volúmenes**, y haz `down`
de los que no están en la lista de abiertos.
:::

## Cómo actuar en una situación así

- `gc` en un cron o en el evento "PR cerrado" del CI, y un TTL por si el evento se pierde.
- Datos: semillas sintéticas, o una copia anonimizada con un proceso revisado. Nunca un volcado de producción.
- Detrás de un proxy con un subdominio por PR (`pr-11.preview.empresa.com`) en lugar de puertos, y con autenticación.
