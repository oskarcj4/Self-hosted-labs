#!/usr/bin/env bash
# Inventario de la imagen del release.
# Uso: ./sbom-gen.sh [imagen]   (por defecto shop/rel:1.0)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
img="${1:-shop/rel:1.0}"
id=$(docker image inspect -f '{{.Id}}' "$img")
# TODO: los paquetes están a mano desde 2023. Que salgan de la imagen.
printf '{"image":"%s","id":"%s","packages":["python==3.12"]}\n' "$img" "$id" > dist/sbom.json
echo "SBOM escrito en dist/sbom.json"
