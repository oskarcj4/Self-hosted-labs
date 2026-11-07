#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/monorepo
cat > ci/changed.sh <<'SH'
#!/usr/bin/env bash
# changed.sh <base> <head> — servicios afectados por los cambios base..head.
set -euo pipefail
files=$(git diff --name-only "$1" "$2")
[ -n "$files" ] || exit 0
for d in services/*/; do
  s=$(basename "$d")
  # Rutas que afectan a $s: su carpeta y lo que declare en deps.txt.
  rutas="services/$s"
  [ -f "$d/deps.txt" ] && rutas="$rutas $(grep -v '^\s*#' "$d/deps.txt" | sed 's:/*$::' || true)"
  for r in $rutas; do
    if grep -q -e "^$r/" -e "^$r\$" <<< "$files"; then echo "$s"; break; fi
  done
done | sort -u
SH
cat > ci/pipeline.sh <<'SH'
#!/usr/bin/env bash
# Pipeline del monorepo: construye sólo los servicios afectados.
set -euo pipefail
afectados=$(bash ci/changed.sh "$CI_BASE" "$CI_HEAD")
if [ -z "$afectados" ]; then
  echo "Nada que construir: ningún servicio afectado."
  exit 0
fi
echo "Afectados: $(echo $afectados)"
for s in $afectados; do
  bash ci/build.sh "$s"
done
SH
chmod 0755 ci/*.sh
git add -A
git commit -qm "CI: construir sólo los servicios afectados"
ci-run
echo "solve.sh completado."
