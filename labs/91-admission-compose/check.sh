#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
as_an(){ if [ "$(id -u)" = 0 ]; then su -s /bin/bash analista -c "$1"; else bash -c "$1"; fi; }
P=/home/analista/shipyard
T=$(mktemp -d /tmp/rt91.XXXXXX); chmod 755 "$T"
cleanup(){ docker compose -p evil91 down -t 1 >/dev/null 2>&1; rm -rf "$T"; }

echo "== Lab 91 · Admission Compose — comprobación =="

# ---------- corpus de red team (oculto) ----------
mkdir -p "$T/deny" "$T/allow"
cat > "$T/deny/basic.yaml" <<'EOF'
services:
  x: {image: python:3.12-alpine, privileged: true, pid: host, network_mode: host,
      volumes: ["/var/run/docker.sock:/var/run/docker.sock"]}
EOF
cat > "$T/deny/interp.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    privileged: ${PRIV:-true}
EOF
cat > "$T/deny/varrun.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    volumes:
      - type: bind
        source: /var/run
        target: /hostrun
EOF
cat > "$T/deny/rootfs.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    volumes:
      - /:/host:ro
EOF
cat > "$T/deny/runsock.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    volumes:
      - ${SOCK_DIR:-/run}/docker.sock:/s
EOF
cat > "$T/deny/caps.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    cap_add: ["CAP_SYS_ADMIN"]
EOF
cat > "$T/deny/quoted.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    network_mode:   "host"
EOF
cat > "$T/deny/pidhost.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    pid: 'host'
EOF
cat > "$T/deny/base.yaml" <<'EOF'
services:
  base:
    image: python:3.12-alpine
    privileged: true
EOF
cat > "$T/deny/extends.yaml" <<'EOF'
services:
  x:
    extends:
      file: base.yaml
      service: base
EOF
cat > "$T/deny/second.yaml" <<'EOF'
services:
  web:
    image: python:3.12-alpine
  sidecar:
    image: python:3.12-alpine
    ipc: host
EOF
cat > "$T/deny/seccomp.yaml" <<'EOF'
services:
  x:
    image: python:3.12-alpine
    security_opt: ["seccomp=unconfined"]
EOF
cat > "$T/deny/broken.yaml" <<'EOF'
services:
  x: [image: python:3.12-alpine
    privileged
EOF
cat > "$T/allow/commented.yaml" <<'EOF'
# Antes: privileged: true y /var/run/docker.sock montado. Ya no.
services:
  api:
    image: python:3.12-alpine
    environment:
      NOTE: "nunca montes /var/run/docker.sock ni pongas network_mode: host"
    volumes:
      - data:/data
      - ./conf:/conf:ro
volumes:
  data: {}
EOF
cat > "$T/allow/hardened.yaml" <<'EOF'
services:
  api:
    image: python:3.12-alpine
    read_only: true
    cap_drop: [ALL]
    cap_add: [NET_BIND_SERVICE]
    security_opt: ["no-new-privileges:true"]
EOF

leak=""; fp=""
for f in "$T"/deny/*.yaml; do
  [ "$(basename "$f")" = base.yaml ] && continue
  if (cd "$T/deny" && "$P/admit.sh" "$f") >/dev/null 2>&1; then leak="$leak $(basename "$f" .yaml)"; fi
done
for f in "$T"/allow/*.yaml; do
  (cd "$T/allow" && "$P/admit.sh" "$f") >/dev/null 2>&1 || fp="$fp $(basename "$f" .yaml)"
done
[ -z "$leak" ] && ok "admit.sh rechaza los 12 manifiestos de red team." \
  || no "admit.sh deja pasar:$leak"
[ -z "$fp" ] && ok "admit.sh acepta los manifiestos legítimos (sin falsos positivos)." \
  || no "admit.sh rechaza manifiestos legítimos:$fp"

if (cd "$P" && ./admit.sh compose.yaml) >/tmp/ad91.out 2>&1; then
  ok "admit.sh acepta compose.yaml."
else
  no "admit.sh rechaza tu compose.yaml:"; sed 's/^/      /' /tmp/ad91.out
fi
rm -f /tmp/ad91.out

# ---------- deploy.sh tiene que frenar un manifiesto malo ----------
cp -r "$P" "$T/ship"
cat > "$T/ship/compose.yaml" <<'EOF'
name: evil91
services:
  x:
    image: python:3.12-alpine
    command: ["sleep", "300"]
    privileged: ${PRIV:-true}
EOF
chown -R analista:analista "$T/ship" 2>/dev/null
if as_an "bash '$T/ship/deploy.sh'" >/dev/null 2>&1; then
  no "deploy.sh terminó 0 con un manifiesto privilegiado."
elif [ -n "$(docker ps -aq --filter label=com.docker.compose.project=evil91)" ]; then
  no "deploy.sh falló, pero el contenedor malo llegó a crearse."
else
  ok "deploy.sh aborta antes de compose up cuando admit.sh dice DENY."
fi
cleanup

# ---------- runtime ----------
c=$(docker ps -q --filter label=com.docker.compose.project=shipyard --filter label=com.docker.compose.service=api | head -1)
if [ -z "$c" ]; then
  no "api no está corriendo (¿./deploy.sh tras arreglar el YAML?)."
else
  [ "$(docker inspect -f '{{.HostConfig.Privileged}}' "$c")" = "false" ] \
    && ok "api no es privileged." || no "api sigue privileged."
  docker inspect -f '{{range .Mounts}}{{.Source}} {{end}}' "$c" | grep -q docker.sock \
    && no "api sigue con docker.sock." || ok "api sin docker.sock."
fi

if curl -sf --max-time 3 http://127.0.0.1:8080/ | grep -q 'api ok'; then
  ok "La api responde."
else
  no "curl :8080 no devuelve api ok."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Admisión real en el camino del deploy. ¡Lab 91 resuelto!"; exit 0; } || exit 1
