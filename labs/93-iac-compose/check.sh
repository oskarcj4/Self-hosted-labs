#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/iac
T=$(mktemp -d /tmp/rt93.XXXXXX)

echo "== Lab 93 · Scan IaC — comprobación =="

# ---------- corpus oculto ----------
mkdir -p "$T/deny" "$T/allow"
w(){ cat > "$T/$1.yaml"; }
w deny/implicit <<'EOF'
services: {api: {image: shop/api, user: "10001"}}
EOF
w deny/latest-quoted <<'EOF'
services:
  api:
    image: "shop/api:latest"
    user: "10001"
EOF
w deny/registry-port <<'EOF'
services:
  api:
    image: localhost:5000/shop/api
    user: "10001"
EOF
w deny/user-missing <<'EOF'
services:
  api:
    image: shop/api:1.2.0
EOF
w deny/user-root <<'EOF'
services:
  api:
    image: shop/api:1.2.0
    user: root
EOF
w deny/user-zero-group <<'EOF'
services:
  api:
    image: shop/api:1.2.0
    user: "0:1000"
EOF
w deny/second-service <<'EOF'
services:
  api:
    image: shop/api:1.2.0
    user: "10001"
  worker:
    image: shop/worker:2.0.1
EOF
w deny/priv-interp <<'EOF'
services:
  api:
    image: shop/api:1.2.0
    user: "10001"
    privileged: ${X:-true}
EOF
w deny/sock-long <<'EOF'
services:
  api:
    image: shop/api:1.2.0
    user: "10001"
    volumes:
      - type: bind
        source: /run/docker.sock
        target: /var/run/docker.sock
EOF
w deny/broken <<'EOF'
services:
  api: {image: shop/api:1.2.0, user: "10001"
EOF
w allow/registry-tag <<'EOF'
services:
  api:
    image: localhost:5000/shop/api:1.2.0
    user: "10001:10001"
EOF
w allow/digest <<'EOF'
services:
  api:
    image: python@sha256:0d3a2e3bd6c9a3d2c7b6fa0f8a9e6d1c2b3a4f5e6d7c8b9a0f1e2d3c4b5a6f7e
    user: nobody
EOF
w allow/comments <<'EOF'
# Antes: image: shop/api:latest, privileged: true y /var/run/docker.sock. Ya no.
services:
  api:
    image: shop/api:1.2.0
    user: "10001"
    environment:
      NOTE: "no uses :latest ni docker.sock"
EOF

leak=""; fp=""
for f in "$T"/deny/*.yaml; do
  "$P/scan.sh" "$f" >/dev/null 2>&1 && leak="$leak $(basename "$f" .yaml)"
done
for f in "$T"/allow/*.yaml; do
  "$P/scan.sh" "$f" >/dev/null 2>&1 || fp="$fp $(basename "$f" .yaml)"
done
[ -z "$leak" ] && ok "scan.sh detecta los 10 casos malos del corpus." \
  || no "Falsos negativos:$leak"
[ -z "$fp" ] && ok "scan.sh acepta los casos buenos (sin falsos positivos)." \
  || no "Falsos positivos:$fp"
rm -rf "$T"

if (cd "$P" && ./test-scan.sh) >/dev/null 2>&1; then ok "./test-scan.sh en verde."
else no "./test-scan.sh falla."; fi

if (cd "$P" && ./scan.sh compose.yaml) >/tmp/s93.out 2>&1; then
  ok "compose.yaml limpio."
else
  no "compose.yaml tiene hallazgos:"; sed 's/^/      /' /tmp/s93.out
fi
rm -f /tmp/s93.out

# ---------- runtime ----------
c=$(docker ps -q --filter label=com.docker.compose.project=iac --filter label=com.docker.compose.service=api | head -1)
if [ -z "$c" ]; then
  no "api no está corriendo."
else
  [ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$c")" = "false" ] \
    && ok "Runtime no privileged." || no "Runtime privileged."
  u=$(docker inspect -f '{{.Config.User}}' "$c")
  case "${u%%:*}" in
    ""|root|0) no "Runtime corre como root (user='$u')." ;;
    *) ok "Runtime user=$u." ;;
  esac
  img=$(docker inspect -f '{{.Config.Image}}' "$c")
  last=${img##*/}
  if [[ "$img" == *@sha256:* ]] || [[ "$last" == *:* && "$last" != *:latest ]]; then
    ok "Imagen con versión fija ($img)."
  else
    no "Imagen en runtime sin tag fijo ($img)."
  fi
fi

if curl -sf --max-time 3 http://127.0.0.1:8080/ | grep -q 'api ok'; then
  ok "La api responde."
else
  no "curl :8080 no devuelve api ok."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Escáner con tests y compose limpio de verdad. ¡Lab 93 resuelto!"; exit 0; } || exit 1
