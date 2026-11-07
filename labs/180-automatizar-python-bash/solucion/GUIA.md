# Resolución guiada · Lab 180

:::piensa ¿Qué hace rotar-backups.sh sin argumento?
`DIR` vacío, así que `cd $DIR` es `cd` a secas: te lleva a HOME. Después borra
todo menos los 7 ficheros más recientes **de tu HOME**. Ese es el tipo de
script que causa incidentes.
:::

## Paso 1 · Bash defensivo

:::pista Qué cambiar
- `set -euo pipefail` y validar los argumentos antes de tocar nada.
- Nada de `for f in $(ls)`: se rompe con espacios. Usa `find -printf` o un glob.
- Ordena por el **nombre** (la fecha `AAAA-MM-DD` ordena bien como texto), no por `ls -t`.
- `rm -f -- "$dir/$f"`, siempre con comillas.
:::

:::pista El cerrojo
```bash
exec 9>"$dir/.rotar.lock"
flock -n 9 || { echo "otra rotación en curso" >&2; exit 3; }
```
Si cron lanza la siguiente ejecución antes de que acabe la anterior, la nueva
sale al momento.
:::

## Paso 2 · Qué conservar

:::pista Cómo hacerlo
Con la lista ordenada en un array, los índices `>= n-7` son los 7 más
recientes. `${f:11:2}` es el día dentro de `db-AAAA-MM-DD.tar.gz`.
:::

## Paso 3 · Python

:::pista Qué cambiar
- `argparse` con `nargs="+"` y `--umbral`.
- Una expresión regular del formato combined: lo que no case se cuenta en
  `descartadas` y no rompe el script.
- `ruta.split("?", 1)[0]` y `sorted(..., key=lambda x: (-x[1], x[0]))`.
- `print(json.dumps(...))` y `sys.exit(1 if tasa > umbral else 0)`.
:::

## Cómo actuar en una situación así

- `--dry-run` en todo lo que borre: ejecútalo primero y lee la salida.
- Los códigos de salida son la interfaz con cron, CI y otros scripts.
- `shellcheck` en el pipeline, igual que un linter de cualquier otro lenguaje.
