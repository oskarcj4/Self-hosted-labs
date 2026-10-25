#!/usr/bin/env bash
set -e
P=/home/analista/trace-ci
cat > "$P/run-ci.sh" <<'EOF'
#!/usr/bin/env bash
# Runner de CI casero: carga secretos, corre jobs/*.sh en orden, guarda el log
# y "sube" dist/ como artefacto público del build (artifacts/).
set -euo pipefail
cd "$(dirname "$0")"
rm -rf dist artifacts
mkdir -p dist logs artifacts
set -a
# shellcheck disable=SC1091
. secrets/deploy_token
set +a
# Sustitución literal (no regex): el valor del secreto nunca llega al log.
mask() {
  local line
  while IFS= read -r line || [ -n "$line" ]; do
    printf '%s\n' "${line//"$DEPLOY_TOKEN"/***}"
  done
}
{
  echo "=== ci $(date -Iseconds) ==="
  for job in jobs/*.sh; do
    echo "--- $job"
    bash "$job"
  done
} 2>&1 | mask | tee logs/last-run.log
cp -r dist/. artifacts/
EOF
cat > "$P/jobs/10-build.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "build $(date +%s)" > dist/build.txt
echo "build ok"
EOF
cat > "$P/jobs/20-deploy.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${DEPLOY_TOKEN:?}"
# La cabecera va por stdin: ni log, ni artefacto, ni argv (visible en ps).
printf 'Authorization: Bearer %s\n' "$DEPLOY_TOKEN" | bin/push -
echo ok > dist/ok.txt
EOF
chmod 0755 "$P/run-ci.sh" "$P/jobs/"*.sh
chown -R analista:analista "$P"
su -s /bin/bash analista -c "cd '$P' && ./run-ci.sh"
