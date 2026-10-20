#!/usr/bin/env bash
# Helper para manejar los labs de TerminalCero Lab.
#
# Auto-destrucción (igual que la web): `check` que pasa destruye el lab; al
# salir de la sesión de `start` el lab se destruye (si está resuelto, siempre;
# si no, salvo que respondas "n"). `reap` limpia labs resueltos o parados.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABS="$ROOT/labs"
MARKER=/tmp/.tclab-solved

usage() {
  cat <<EOF
TerminalCero Lab

Uso: ./lab.sh <comando> [lab]

Comandos:
  list              Lista los labs disponibles
  start <NN>        Construye y entra al lab NN (se destruye al salir)
  check <NN>        Ejecuta el validador del lab NN (si pasa, lo destruye)
  solution <NN>     Muestra la solución del lab NN
  reset <NN>        Re-planta el escenario (reconstruye el contenedor)
  stop <NN>         Apaga y destruye el lab NN
  stop-all          Apaga y destruye todos los labs
  reap              Destruye labs resueltos o parados que hayan quedado
  web               Lanza la interfaz web (http://localhost:8099)

Ejemplo: ./lab.sh start 01
EOF
}

lab_dir() {
  local n="$1"
  local d
  d="$(find "$LABS" -maxdepth 1 -type d -name "${n}-*" | head -1)"
  [ -n "$d" ] || { echo "No existe el lab '$n'. Usa ./lab.sh list" >&2; exit 1; }
  echo "$d"
}

compose() { docker compose -f "$1/docker-compose.yml" "${@:2}"; }
destroy() { echo ">>> Destruyendo lab $(basename "$1")…"; compose "$1" down -v --remove-orphans -t 5; }
lab_id() { basename "$1" | cut -d- -f1; }
solved() { docker exec "tc-lab-$(lab_id "$1")" test -e "$MARKER" 2>/dev/null; }

cmd="${1:-}"; shift || true
case "$cmd" in
  list)
    echo "Labs disponibles:"
    for d in "$LABS"/*/; do
      n="$(basename "$d")"
      title="$(grep -m1 '^# ' "$d/RETO.md" 2>/dev/null | sed 's/^# //')"
      printf "  %-32s %s\n" "$n" "$title"
    done
    ;;
  start)
    d="$(lab_dir "$1")"
    compose "$d" up -d --build
    echo ">>> Entrando al lab. Lee el reto con:  cat /RETO.md"
    echo ">>> Al salir de la shell el lab se autodestruye."
    if compose "$d" exec -T lab test -f /opt/lab/enter.sh; then
      compose "$d" exec lab bash /opt/lab/enter.sh || true   # espera a que el escenario esté listo
    else
      compose "$d" exec lab bash -c 'su - analista' || true
    fi
    if solved "$d"; then
      destroy "$d"
    else
      ans=s
      [ -t 0 ] && read -r -p "Lab sin resolver. ¿Destruirlo igualmente? [S/n] " ans
      case "${ans:-s}" in n|N|no|NO) echo ">>> Se mantiene. Destrúyelo con: ./lab.sh stop $1";; *) destroy "$d";; esac
    fi
    ;;
  check)
    d="$(lab_dir "$1")"
    if compose "$d" exec -T lab bash /opt/lab/check.sh; then
      destroy "$d"
    else
      exit 1
    fi
    ;;
  solution)
    d="$(lab_dir "$1")"
    ${PAGER:-less} "$d/solucion/SOLUCION.md"
    ;;
  reset)
    d="$(lab_dir "$1")"
    compose "$d" down -v --remove-orphans -t 5
    compose "$d" up -d --build --force-recreate
    echo ">>> Escenario re-plantado."
    ;;
  stop)
    d="$(lab_dir "$1")"
    destroy "$d"
    ;;
  stop-all)
    for d in "$LABS"/*/; do compose "$d" down -v --remove-orphans -t 5 || true; done
    ;;
  reap)
    docker ps -a --filter name=tc-lab- --format '{{.Names}} {{.State}}' | while read -r name state; do
      [[ "$name" =~ ^tc-lab-([0-9]{2})$ ]] || continue
      d="$(lab_dir "${BASH_REMATCH[1]}")"
      if [ "$state" != running ] || solved "$d"; then destroy "$d"; fi
    done
    ;;
  web)
    PY="$(command -v python3 || command -v python)"   # Windows suele traer sólo "python"
    exec "$PY" "$ROOT/server.py"
    ;;
  ""|-h|--help|help) usage ;;
  *) echo "Comando desconocido: $cmd" >&2; usage; exit 1 ;;
esac
