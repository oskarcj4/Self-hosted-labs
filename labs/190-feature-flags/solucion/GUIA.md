# Resolución guiada · Lab 190

:::piensa ¿Qué tiene que pasar a las 3 de la mañana si el checkout nuevo falla?
Alguien cambia `activo` a `false` y, en segundos, nadie lo ve. Sin
despliegue, sin reinicio y sin miedo a romper otra cosa. Diseña para ese
momento.
:::

## Paso 1 · Leer el fichero en caliente

:::pista Cómo hacerlo
Un módulo `flags.py` que guarda la configuración en memoria y, como mucho
una vez por segundo, mira `os.stat()`. Si cambió `mtime` o el tamaño, lo
vuelve a leer. Usa un `Lock`: el servidor tiene hilos.
:::

## Paso 2 · El fichero roto

:::pista Cómo hacerlo
Haz el `json.load` en un `try`. Si falla, deja la configuración anterior y
registra un aviso. Si nunca hubo una buena, el diccionario vacío significa
"todo apagado".
:::

## Paso 3 · Porcentaje estable

:::pista Cómo hacerlo
`cubeta = sha256("nuevo_checkout:u-42") % 100` y "nuevo" si
`cubeta < porcentaje`. Mismo usuario, misma cubeta. Al subir el porcentaje
sólo entran usuarios nuevos. Meter el nombre del flag en el hash evita que
los mismos usuarios sean siempre los conejillos de indias de todos los flags.
:::

## Paso 4 · Orden de las reglas

:::pista Qué hacer
`activo` primero (gana a todo), luego la lista de usuarios y luego el porcentaje.
:::

## Paso 5 · Limpiar

:::pista Qué hacer
Borra `BANNER_NAVIDAD_2023`, `banner()` y las líneas `Environment=` de la
unidad (`daemon-reload` y reinicia una vez).
:::

## Cómo actuar en una situación así

- Cada flag con dueño y fecha de caducidad. Revisa los flags viejos como cualquier otra deuda técnica.
- Flags de despliegue (temporales) y de configuración (permanentes) no son lo mismo: sepáralos.
- Si un flag decide algo crítico, registra qué valor tenía cada petición (lab 185).
