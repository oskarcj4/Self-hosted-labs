#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /home/analista/inventory
python3 - <<'PY'
import re
s = open("compose.yaml").read()
s = re.sub(r'(  db:\n(?:.*\n)*?)    ports:\n      - "5432:5432".*\n', r'\1', s)
open("compose.yaml", "w").write(s)
PY
docker compose up -d
sleep 2
