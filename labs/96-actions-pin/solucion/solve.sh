#!/usr/bin/env bash
set -e
P=/home/analista/gha-pin
G=/srv/gh
cat > "$P/pin-scan.sh" <<'EOF'
#!/usr/bin/env bash
# Cada 'uses:' remoto (step o reusable workflow) debe apuntar a un commit SHA
# de 40 hex; docker:// a un digest sha256. Las acciones locales (./) viajan
# con tu commit y no necesitan pin.
# Uso: ./pin-scan.sh [workflow.yml]
set -euo pipefail
cd "$(dirname "$0")"
f="${1:-.github/workflows/ci.yml}"
n=0
while IFS= read -r line || [ -n "$line" ]; do
  [[ "$line" =~ ^[[:space:]]*(-[[:space:]]+)?uses:[[:space:]]*(.*)$ ]] || continue
  v="${BASH_REMATCH[2]%%#*}"
  v=$(tr -d "[:space:]\"'" <<<"$v")
  case "$v" in
    ./*) continue ;;
    docker://*) [[ "$v" =~ @sha256:[0-9a-f]{64}$ ]] && continue ;;
    *) [[ "$v" =~ @[0-9a-f]{40}$ ]] && continue ;;
  esac
  echo "UNPINNED: $line"
  n=$((n+1))
done < "$f"
if [ "$n" -gt 0 ]; then
  echo "pin-scan: $n uses sin pin"
  exit 1
fi
echo "pin-scan: todas las actions fijadas"
EOF
c(){ git -C "$G/$1.git" rev-parse "$2^{commit}"; }
cat > "$P/.github/workflows/ci.yml" <<EOF
name: ci
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@$(c actions/checkout v4) # v4.2.2
      - uses: actions/setup-python@$(c actions/setup-python v5) # v5.3.0
      - name: lint
        uses: acme/lint@$(c acme/lint v2) # v2.0.1
      - uses: acme/tool@$(c acme/tool v1.3.0) # v1.3.0 (v1/v1.3.1 comprometidos, GHSA-tc96)
      - uses: ./.github/actions/local-setup
      - run: python -m pytest
  release:
    needs: test
    uses: acme/workflows/.github/workflows/release.yml@$(c acme/workflows main) # main
EOF
chmod 0755 "$P/pin-scan.sh"
chown -R analista:analista "$P"
cd "$P" && ./pin-scan.sh
