#!/usr/bin/env bash
set -euo pipefail
test -n "${DEPLOY_TOKEN:-}" || { echo "falta DEPLOY_TOKEN"; exit 1; }
test -f dist/shop.txt || { echo "no hay artefacto"; exit 1; }
echo "deploy ok" > dist/deployed.txt
