#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
S=${SCRIPTS:-$HOME/scripts}

cat > "$S/rotar-backups.sh" <<'SH'
#!/usr/bin/env bash
# Rota los backups de DIR: conserva los 7 más recientes (por la fecha del
# nombre) y los del día 01 de cada mes. Uso: rotar-backups.sh DIR [--dry-run]
set -euo pipefail

uso() { echo "uso: $0 DIR [--dry-run]" >&2; exit 2; }

if [ $# -lt 1 ] || [ -z "$1" ]; then uso; fi
dir=$1
seco=0
[ "${2:-}" = "--dry-run" ] && seco=1
[ -d "$dir" ] || { echo "error: '$dir' no es un directorio" >&2; exit 2; }

# Un único proceso a la vez sobre el mismo directorio.
exec 9>"$dir/.rotar.lock"
flock -n 9 || { echo "error: otra rotación en curso en '$dir'" >&2; exit 3; }

# Sólo nombres exactos db-AAAA-MM-DD.tar.gz; el orden por nombre es el orden por fecha.
mapfile -t backups < <(find "$dir" -maxdepth 1 -type f -regextype posix-extended \
  -regex '.*/db-[0-9]{4}-[0-9]{2}-[0-9]{2}\.tar\.gz' -printf '%f\n' | sort)

n=${#backups[@]}
for i in "${!backups[@]}"; do
  f=${backups[$i]}
  [ "$i" -ge $((n - 7)) ] && continue          # los 7 más recientes
  [ "${f:11:2}" = "01" ] && continue           # mensuales: db-AAAA-MM-01
  if [ "$seco" -eq 1 ]; then
    echo "borraría: $f"
  else
    rm -f -- "$dir/$f"
    echo "borrado: $f"
  fi
done
SH

cat > "$S/informe_errores.py" <<'PY'
#!/usr/bin/env python3
"""Informe de errores 5xx a partir de logs de nginx (formato combined).

Uso: informe_errores.py LOG [LOG...] [--umbral 0.05]
Salida: JSON. Código 1 si la tasa de 5xx supera el umbral, 2 si falta un fichero.
"""
import argparse, collections, gzip, json, re, sys

LINEA = re.compile(
    r'^(?P<ip>\S+) \S+ \S+ \[(?P<ts>[^\]]+)\] "(?P<metodo>[A-Z]+) (?P<ruta>\S+) (?P<proto>[^"\s]+)" '
    r'(?P<estado>\d{3}) (?P<bytes>\d+|-) "(?P<referer>[^"]*)" "(?P<ua>[^"]*)"$')


def abrir(ruta):
    return gzip.open(ruta, "rt", errors="replace") if ruta.endswith(".gz") else open(ruta, errors="replace")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("logs", nargs="+")
    ap.add_argument("--umbral", type=float, default=0.05)
    a = ap.parse_args()

    total = errores = descartadas = 0
    por_ruta = collections.Counter()
    for ruta in a.logs:
        try:
            f = abrir(ruta)
        except OSError as e:
            print(f"error: {e}", file=sys.stderr)
            return 2
        with f:
            for linea in f:
                m = LINEA.match(linea.rstrip("\n"))
                if not m:
                    descartadas += 1
                    continue
                total += 1
                if m["estado"].startswith("5"):
                    errores += 1
                    por_ruta[m["ruta"].split("?", 1)[0]] += 1

    tasa = round(errores / total, 4) if total else 0
    top = sorted(por_ruta.items(), key=lambda x: (-x[1], x[0]))[:5]
    print(json.dumps({"total": total, "errores_5xx": errores, "tasa": tasa,
                      "top": [{"ruta": r, "n": n} for r, n in top], "descartadas": descartadas},
                     ensure_ascii=False, indent=2))
    return 1 if tasa > a.umbral else 0


if __name__ == "__main__":
    sys.exit(main())
PY
chmod 0755 "$S/rotar-backups.sh" "$S/informe_errores.py"
command -v shellcheck >/dev/null && shellcheck "$S/rotar-backups.sh"
bash "$S/rotar-backups.sh" ~/backups-ejemplo --dry-run | head -3 || true
python3 "$S/informe_errores.py" ~/logs-ejemplo/access.log ~/logs-ejemplo/access.log.1.gz || true
echo "solve.sh completado."
