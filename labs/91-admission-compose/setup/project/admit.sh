#!/usr/bin/env bash
# admit.sh v0 — "política" de admisión del equipo de plataforma.
# Uso: ./admit.sh <compose.yaml>   (0 = ALLOW, ≠0 = DENY)
#
# Rechaza fixtures/bad.yaml, así que "funciona". Red team no opina lo mismo.
set -euo pipefail
f="${1:?uso: ./admit.sh <fichero>}"
if grep -qE 'privileged: true|docker\.sock|pid: host|network_mode: host' "$f"; then
  echo "DENY $f"
  exit 1
fi
echo "ALLOW $f"
