#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/analytics
python3 - <<'PY'
s = open("compose.yaml").read()
s = s.replace("  restart: unless-stopped\n  secrets:\n    - api_token\n", "  restart: unless-stopped\n", 1)
s = s.replace("      ROLE: reporter\n", "      ROLE: reporter\n    secrets:\n      - api_token\n", 1)
open("compose.yaml", "w").write(s)
PY
docker compose up -d
sleep 6
