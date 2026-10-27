#!/usr/bin/env bash
set -e
cd /home/analista/iac
cat > scan.sh <<'EOF'
#!/usr/bin/env bash
# Mini Checkov sobre el compose RENDERIZADO.
# Uso: ./scan.sh [compose.yaml]   (0 = limpio, ≠0 = hallazgos)
set -euo pipefail
f="${1:-compose.yaml}"
if ! json=$(docker compose -f "$f" config --format json 2>/dev/null); then
  echo "HIGH: $f no se puede evaluar (fail-closed)"
  exit 1
fi
hits=$(jq -r '
  .services | to_entries[] | .key as $s | .value |
    ((.image // "") as $img | ($img | split("/") | last) as $last
      | if ($img | test("@sha256:[0-9a-f]{64}$")) then empty
        elif ($last | test(":")) and ($last | test(":latest$") | not) then empty
        else "\($s): imagen sin tag fijo (\($img))" end),
    ((.user // "root") | tostring | split(":")[0]
      | select(. == "" or . == "root" or . == "0") | "\($s): corre como root"),
    (select(.privileged == true) | "\($s): privileged"),
    (.volumes[]? | select(.type == "bind" and (.source | test("docker\\.sock$")))
      | "\($s): monta docker.sock")
' <<<"$json")
if [ -n "$hits" ]; then
  sed 's/^/HIGH: /' <<<"$hits"
  echo "scan: $(wc -l <<<"$hits") hallazgos"
  exit 1
fi
echo "scan: limpio"
EOF
cat > compose.yaml <<'EOF'
name: iac

services:
  api:
    image: shop/api:1.2.0
    build: ./api
    user: "65534:65534"
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF
chown analista: compose.yaml scan.sh
./test-scan.sh
docker compose up -d --build
sleep 2
