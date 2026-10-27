#!/usr/bin/env bash
set -e
cd /home/analista/seccomp
jq '.syscalls |= (map(.names -= ["ptrace", "process_vm_readv", "process_vm_writev"])
                  | map(select(.names | length > 0)))' \
  profiles/docker-default.json > profiles/api.json
cat > compose.yaml <<'EOF'
name: seccomp

services:
  api:
    image: shop/api:1.0
    build: ./api
    security_opt:
      - seccomp=./profiles/api.json
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF
chown analista: compose.yaml profiles/api.json
docker compose up -d --force-recreate
sleep 2
./probe.sh
