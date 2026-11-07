#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/tienda

cat > ci/preview.compose.yaml <<'Y'
# Vista previa de un PR. Lo rellena ci/preview.sh: un proyecto (pr-N) por PR.
services:
  app:
    image: ${PREVIEW_IMAGE:?}
    ports:
      - "127.0.0.1:${PREVIEW_PORT:?}:8000"
    volumes:
      - datos:/datos          # volumen pr-N_datos: vacío, la app lo siembra con datos/semilla.sql
    labels:
      preview.pr: "${PREVIEW_PR:?}"
volumes:
  datos:
Y

cat > ci/preview.sh <<'SH'
#!/usr/bin/env bash
# preview up N    -> vista previa de la rama pr-N en http://127.0.0.1:<9000+N>
# preview down N  -> borra contenedores, red, volumen e imagen del PR N
# preview gc      -> borra las vistas previas de PRs que no están en /srv/prs-abiertos.txt
set -euo pipefail
CI=$(dirname "$(readlink -f "$0")")
REPO=$(dirname "$CI")
BASE=${PREVIEW_DIR:-$HOME/.previews}
ABIERTOS=${PREVIEW_ABIERTOS:-/srv/prs-abiertos.txt}

uso(){ echo "uso: preview up N | down N | gc" >&2; exit 2; }
num(){ [[ "${1:-}" =~ ^[0-9]+$ ]] || uso; }
dc(){ PREVIEW_PR=$1 PREVIEW_PORT=$((9000 + $1)) PREVIEW_IMAGE="tienda:pr-$1" \
      docker compose -p "pr-$1" -f "$CI/preview.compose.yaml" "${@:2}"; }

up(){
  num "$1"; local n=$1 d=$BASE/pr-$1
  git -C "$REPO" rev-parse -q --verify "pr-$n" >/dev/null || { echo "no existe la rama pr-$n" >&2; exit 1; }
  # Exportar la rama a un directorio propio: la copia de trabajo no se toca.
  rm -rf "$d"; mkdir -p "$d"
  git -C "$REPO" archive "pr-$n" | tar -x -C "$d"
  docker build -q -t "tienda:pr-$n" "$d" >/dev/null
  dc "$n" up -d --wait --wait-timeout 60 >/dev/null
  echo "vista previa del PR $n: http://127.0.0.1:$((9000 + n))"
}

down(){
  num "$1"
  dc "$1" down -v --remove-orphans >/dev/null 2>&1 || true
  docker image rm "tienda:pr-$1" >/dev/null 2>&1 || true
  rm -rf "${BASE:?}/pr-$1"
  echo "vista previa del PR $1 borrada"
}

gc(){
  local n
  for n in $( { docker ps -a --format '{{.Label "com.docker.compose.project"}}'
                docker volume ls --format '{{.Label "com.docker.compose.project"}}'; } \
              | sed -n 's/^pr-\([0-9][0-9]*\)$/\1/p' | sort -un); do
    grep -qx "$n" "$ABIERTOS" 2>/dev/null || down "$n"
  done
}

case "${1:-}" in
  up) up "${2:-}" ;;
  down) down "${2:-}" ;;
  gc) gc ;;
  *) uso ;;
esac
SH
chmod 755 ci/preview.sh

# Restos del script viejo: el proyecto "tienda" y su volumen con la copia de producción.
docker compose -p tienda -f compose.yaml down -v >/dev/null 2>&1 || true
docker volume rm tienda_datos >/dev/null 2>&1 || true

git add ci/
git commit -qm "ci: vistas previas aisladas por PR"
preview up 11
preview up 12
curl -s 127.0.0.1:9011; echo; curl -s 127.0.0.1:9012/clientes; echo
preview down 11; preview down 12
echo "solve.sh completado."
