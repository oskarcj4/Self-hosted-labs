#!/usr/bin/env bash
set -e
P=/home/analista/shipyard
cat > "$P/admit.sh" <<'EOF'
#!/usr/bin/env bash
# Política de admisión sobre el manifiesto RENDERIZADO (lo que Docker ejecuta).
set -euo pipefail
f="${1:?uso: ./admit.sh <compose.yaml>}"
if ! json=$(docker compose -f "$f" config --format json 2>/dev/null); then
  echo "DENY $f: no se puede evaluar (fail-closed)"
  exit 1
fi
deny=$(jq -r '
  def bad_src:
    . == "/" or test("docker\\.sock$")
    or test("^/(var/run|run|proc|sys|etc|var/lib/docker)(/|$)");
  .services | to_entries[] | .key as $s | .value |
    (select(.privileged == true) | "\($s): privileged"),
    ({pid, ipc, network_mode, userns_mode} | to_entries[]
       | select(.value == "host") | "\($s): \(.key)=host"),
    (.volumes[]? | select(.type == "bind" and (.source | bad_src))
       | "\($s): bind \(.source)"),
    (.cap_add[]? | ascii_upcase | ltrimstr("CAP_")
       | select(IN("ALL", "SYS_ADMIN", "SYS_MODULE", "SYS_PTRACE"))
       | "\($s): cap_add \(.)"),
    (.security_opt[]? | select(test("unconfined")) | "\($s): \(.)")
' <<<"$json")
if [ -n "$deny" ]; then
  sed 's/^/DENY /' <<<"$deny"
  exit 1
fi
echo "ALLOW $f"
EOF
cat > "$P/deploy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./admit.sh compose.yaml
docker compose up -d --build
EOF
cat > "$P/compose.yaml" <<'EOF'
name: shipyard

services:
  api:
    image: shop/api:1.0
    build: ./api
    ports:
      - "8080:8080"
    restart: unless-stopped
EOF
chmod 0755 "$P/admit.sh" "$P/deploy.sh"
chown analista:analista "$P/admit.sh" "$P/deploy.sh" "$P/compose.yaml"
su -s /bin/bash analista -c "cd '$P' && ./deploy.sh"
sleep 2
