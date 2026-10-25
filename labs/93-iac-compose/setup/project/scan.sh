#!/usr/bin/env bash
# Mini Checkov: hallazgos HIGH sobre un compose.
# Uso: ./scan.sh [compose.yaml]   (0 = limpio, ≠0 = hallazgos)
set -euo pipefail
f="${1:-compose.yaml}"
n=0
hit() { echo "HIGH: $1"; n=$((n+1)); }
grep -qE 'image:.*:latest' "$f" && hit "tag ':latest' (imagen no reproducible)"
grep -qiE 'privileged:[[:space:]]*true' "$f" && hit "privileged: true"
grep -q 'docker.sock' "$f" && hit "montaje de docker.sock"
grep -qE '^[[:space:]]+user:' "$f" || hit "corre como root (falta user:)"
if [ "$n" -gt 0 ]; then
  echo "scan: $n hallazgos"
  exit 1
fi
echo "scan: limpio"
