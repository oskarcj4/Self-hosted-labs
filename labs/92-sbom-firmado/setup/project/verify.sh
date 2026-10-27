#!/usr/bin/env bash
# Gate de release: ¿el SBOM está firmado?
# Uso: ./verify.sh [imagen]   (por defecto shop/rel:1.0)
set -euo pipefail
cd "$(dirname "$0")"
img="${1:-shop/rel:1.0}"
test -f dist/sbom.json
test -f dist/sbom.json.sig
openssl dgst -sha256 -verify keys/sbom.pub -signature dist/sbom.json.sig dist/sbom.json
echo "OK: release $img verificado"
