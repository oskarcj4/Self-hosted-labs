#!/usr/bin/env bash
# Runner de CI casero: carga secretos, corre jobs/*.sh en orden, guarda el log
# y "sube" dist/ como artefacto público del build (artifacts/).
set -euo pipefail
cd "$(dirname "$0")"
rm -rf dist artifacts
mkdir -p dist logs artifacts
set -a
# shellcheck disable=SC1091
. secrets/deploy_token
set +a
{
  echo "=== ci $(date -Iseconds) ==="
  for job in jobs/*.sh; do
    echo "--- $job"
    bash "$job"
  done
} 2>&1 | tee logs/last-run.log
cp -r dist/. artifacts/
