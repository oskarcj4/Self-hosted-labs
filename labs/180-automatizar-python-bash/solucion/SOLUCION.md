# Solución — Automatizar con Bash y Python

## rotar-backups.sh

```bash
#!/usr/bin/env bash
set -euo pipefail
uso() { echo "uso: $0 DIR [--dry-run]" >&2; exit 2; }
if [ $# -lt 1 ] || [ -z "$1" ]; then uso; fi
dir=$1; seco=0
[ "${2:-}" = "--dry-run" ] && seco=1
[ -d "$dir" ] || { echo "error: '$dir' no es un directorio" >&2; exit 2; }
exec 9>"$dir/.rotar.lock"
flock -n 9 || { echo "error: otra rotación en curso" >&2; exit 3; }
mapfile -t backups < <(find "$dir" -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/db-[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz' -printf '%f\n' | sort)
n=${#backups[@]}
for i in "${!backups[@]}"; do
  f=${backups[$i]}
  [ "$i" -ge $((n - 7)) ] && continue
  [ "${f:11:2}" = "01" ] && continue
  if [ "$seco" -eq 1 ]; then echo "borraría: $f"; else rm -f -- "$dir/$f"; echo "borrado: $f"; fi
done
```

## informe_errores.py

Puntos clave (el fichero completo está en `solve.sh`):

- una regex del formato combined; lo que no case va a `descartadas`;
- `gzip.open(ruta, "rt")` para `.gz`;
- `Counter` de rutas sin query string, ordenado por `(-n, ruta)`;
- `json.dumps` y códigos de salida 0, 1 y 2.

## Errores del original

| Script | Fallo | Consecuencia |
|--------|-------|--------------|
| Bash | `cd $DIR` sin validar | sin argumento, borra en HOME |
| Bash | `$(ls -t)` | se rompe con espacios; ordena por mtime |
| Bash | borra todo lo que no sea de los 7 últimos | se lleva `LEEME.txt` y las copias ajenas |
| Bash | sin cerrojo | dos crons a la vez se pisan |
| Python | `split()[8]` | `IndexError` con una línea rara |
| Python | `print(dict)` | no es JSON: nadie lo puede procesar |
| Python | sin código de salida | CI y alertas no pueden reaccionar |

## Más allá del lab

- `bats` para probar scripts de Bash; `pytest` para los de Python.
- Si un script pasa de unas 100 líneas o necesita estructuras de datos, pásalo a Python.
- `systemd-run --on-calendar` o un timer en lugar de cron: logs en el journal y sin solapes.
