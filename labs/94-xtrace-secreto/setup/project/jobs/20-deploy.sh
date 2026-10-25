#!/usr/bin/env bash
# Debug "temporal" de 2024: xtrace imprime cada expansión, incluido el token.
set -x
set -euo pipefail
: "${DEPLOY_TOKEN:?}"
# Soporte pidió poder comprobar el token en los logs sin "verlo".
echo "debug: auth=$(printf '%s' "$DEPLOY_TOKEN" | base64)"
echo "Authorization: Bearer ${DEPLOY_TOKEN}" > dist/hdr.txt
bin/push dist/hdr.txt
echo ok > dist/ok.txt
