#!/usr/bin/env bash
# Mini runner: inyecta env: del YAML, opcionalmente secrets/deploy_token, ejecuta jobs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
mkdir -p dist logs
export_yaml_env() {
  python3 - <<'PY'
import os, re
text = open("pipeline.yml", encoding="utf-8").read()
block = re.search(r"^env:\n((?:[ \t]+.+\n)+)", text, re.M)
if not block:
    raise SystemExit
for line in block.group(1).splitlines():
    m = re.match(r'\s+([A-Z][A-Z0-9_]*):\s*"([^"]*)"', line)
    if m:
        print(f"export {m.group(1)}='{m.group(2)}'")
PY
}
eval "$(export_yaml_env || true)"
if [ -f secrets/deploy_token ]; then
  set -a
  # shellcheck disable=SC1091
  . secrets/deploy_token
  set +a
fi
{
  echo "=== ci $(date -Iseconds) ==="
  if grep -qE 'pull_request' pipeline.yml; then
    echo "event=pull_request secrets=enabled"
  else
    echo "event=push"
  fi
  bash jobs/build.sh
  bash jobs/deploy.sh
} 2>&1 | tee logs/last-run.log
