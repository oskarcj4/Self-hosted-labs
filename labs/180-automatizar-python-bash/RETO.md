# Automatizar con Bash y Python, pero bien

> DevOps · Bash estricto · shellcheck · flock · Python con argparse · códigos de salida

## Escenario

En `~/scripts` hay dos scripts que se usan en producción:

- `rotar-backups.sh` borra backups viejos desde cron. **No lo ejecutes tal
  cual**: léelo y piensa qué pasa si lo lanzas sin argumento.
- `informe_errores.py` resume los 5xx de nginx. No lee `.gz`, se cae con una
  línea rara y su salida no la puede leer otra herramienta.

Un script de operaciones es software: necesita entradas validadas, salida
procesable, códigos de salida con significado y pruebas. El check prueba los
tuyos con **datos que no has visto**.

## Objetivos

La especificación completa está en `~/TAREA.txt`. En resumen:

1. `rotar-backups.sh DIR [--dry-run]`:
   - valida DIR (código 2);
   - sólo toca `db-AAAA-MM-DD.tar.gz`;
   - conserva los 7 más recientes por la fecha del nombre y los del día 01;
   - imprime `borrado:` o `borraría:`;
   - usa un cerrojo con `flock` (código 3);
   - pasa `shellcheck` sin avisos.
2. `informe_errores.py LOG... [--umbral]`:
   - lee logs planos y `.gz`;
   - imprime JSON con total, errores, tasa, top 5 y líneas descartadas;
   - sale con código 0, 1 o 2.

## Pistas

```bash
set -euo pipefail                      # fallar pronto y en voz alta
[ -d "$dir" ] || { echo "..." >&2; exit 2; }
exec 9>"$dir/.rotar.lock"; flock -n 9 || exit 3
find "$dir" -maxdepth 1 -type f -name 'db-*' -printf '%f\n' | sort
rm -f -- "$dir/$f"                     # comillas siempre; -- por si el nombre empieza por -
shellcheck ~/scripts/rotar-backups.sh
```

```python
import argparse, gzip, json, re, sys
gzip.open(ruta, "rt")                  # .gz como texto
sys.exit(1)                            # el código de salida es parte de la interfaz
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
