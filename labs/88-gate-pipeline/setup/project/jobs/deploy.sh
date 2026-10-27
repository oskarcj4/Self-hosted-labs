#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p dist
echo deployed > dist/deployed.txt
echo "deploy ok"
