#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if grep -RInE 'PASSWORD[[:space:]]*=[[:space:]]*"' app >/dev/null 2>&1; then
  echo "secret-scan: hallazgo — contraseña hardcodeada en app/"
  grep -RInE 'PASSWORD[[:space:]]*=[[:space:]]*"' app || true
  exit 1
fi
echo "secret-scan: limpio"
