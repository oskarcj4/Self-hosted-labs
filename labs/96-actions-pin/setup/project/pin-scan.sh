#!/usr/bin/env bash
# Cada 'uses:' debe apuntar a un SHA de 40 hex, no a un tag flotante.
# Uso: ./pin-scan.sh [workflow.yml]
set -euo pipefail
cd "$(dirname "$0")"
f="${1:-.github/workflows/ci.yml}"
n=0
while IFS= read -r line; do
  echo "$line" | grep -qE '^[[:space:]]*-[[:space:]]*uses:' || continue
  ref=$(echo "$line" | sed -n 's/.*@//p' | tr -d '[:space:]"')
  if echo "$ref" | grep -qiE '^[0-9a-f]{40}'; then
    continue
  fi
  echo "UNPINNED: $line"
  n=$((n+1))
done < "$f"
if [ "$n" -gt 0 ]; then
  echo "pin-scan: $n uses sin SHA"
  exit 1
fi
echo "pin-scan: todas las actions fijadas a SHA"
