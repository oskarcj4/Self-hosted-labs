#!/usr/bin/env bash
# Tests del escáner: todo tests/deny/* debe dar ≠0 y todo tests/allow/* 0.
# Añade casos aquí. El check trae más.
cd "$(dirname "$0")"
bad=0
for f in tests/deny/*.yaml; do
  if ./scan.sh "$f" >/dev/null 2>&1; then echo "FALSO NEGATIVO  $f"; bad=1; fi
done
for f in tests/allow/*.yaml; do
  if ! ./scan.sh "$f" >/dev/null 2>&1; then echo "FALSO POSITIVO  $f"; bad=1; fi
done
[ "$bad" -eq 0 ] && echo "test-scan: OK" || { echo "test-scan: FALLA"; exit 1; }
