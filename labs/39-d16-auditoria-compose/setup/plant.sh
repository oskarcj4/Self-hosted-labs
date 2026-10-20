#!/usr/bin/env bash
# Lab 39 (Día 16): stack Compose corriendo con un override de "hotfix" que ya
# no existe en disco. El estado real difiere de compose.yaml y del README.
set -e
P=/home/analista/handoff
mkdir -p "$P" /home/analista/audit
cp -r /opt/lab/setup/project/. "$P/"
cd "$P"
docker build -q -t handoff/app:1.0 ./app

# Hotfix aplicado durante un incidente (ticket 4411) y luego borrado del disco.
cat > hotfix-4411.yaml <<'EOF'
services:
  web:
    ports: !override
      - "8443:8080"
EOF
docker compose -f compose.yaml -f hotfix-4411.yaml up -d
rm -f hotfix-4411.yaml

chown -R analista:analista "$P" /home/analista/audit
echo "Lab 39 plantado."
