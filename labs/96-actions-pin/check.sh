#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/gha-pin
G=/srv/gh
wf="$P/.github/workflows/ci.yml"
T=$(mktemp -d /tmp/rt96.XXXXXX)
S40=11bd71901bbe49a263013c35afe454c0f769b6d3
D64=$(printf 'a%.0s' $(seq 64))

echo "== Lab 96 · Pin de Actions — comprobación =="

# ---------- corpus oculto para pin-scan.sh ----------
mkdir -p "$T/deny" "$T/allow"
w(){ cat > "$T/$1.yml"; }
w deny/named-step <<'EOF'
jobs:
  t:
    steps:
      - name: lint
        uses: acme/lint@v2
EOF
w deny/reusable <<'EOF'
jobs:
  release:
    uses: acme/workflows/.github/workflows/release.yml@main
EOF
w deny/quoted <<'EOF'
jobs:
  t:
    steps:
      - uses: "actions/checkout@main"
EOF
w deny/short-sha <<'EOF'
jobs:
  t:
    steps:
      - uses: actions/checkout@11bd719
EOF
w deny/sha-in-comment <<EOF
jobs:
  t:
    steps:
      - uses: actions/checkout@v4 # $S40
EOF
w deny/sha-prefix <<EOF
jobs:
  t:
    steps:
      - uses: actions/checkout@${S40}-evil
EOF
w deny/docker-tag <<'EOF'
jobs:
  t:
    steps:
      - uses: docker://alpine:3.20
EOF
w allow/pinned <<EOF
jobs:
  t:
    steps:
      - uses: actions/checkout@$S40 # v4.2.2
      - name: x
        uses: 'acme/lint@$S40'
      - uses: ./.github/actions/local-setup
      - uses: docker://alpine@sha256:$D64
      - run: echo "uses: acme/tool@main en un string no es un uses"
  release:
    uses: acme/workflows/.github/workflows/release.yml@$S40
EOF
leak=""; fp=""
for f in "$T"/deny/*.yml; do "$P/pin-scan.sh" "$f" >/dev/null 2>&1 && leak="$leak $(basename "$f" .yml)"; done
for f in "$T"/allow/*.yml; do "$P/pin-scan.sh" "$f" >/dev/null 2>&1 || fp="$fp $(basename "$f" .yml)"; done
[ -z "$leak" ] && ok "pin-scan.sh detecta los 7 uses sin pin del corpus." || no "pin-scan.sh deja pasar:$leak"
[ -z "$fp" ] && ok "pin-scan.sh acepta locales, digests y SHA con comentario." || no "pin-scan.sh rechaza casos buenos:$fp"
rm -rf "$T"

if (cd "$P" && ./pin-scan.sh) >/tmp/p96.out 2>&1; then
  ok "pin-scan.sh limpio sobre ci.yml."
else
  no "pin-scan.sh sigue en rojo sobre ci.yml:"; sed 's/^/      /' /tmp/p96.out
fi
rm -f /tmp/p96.out

# ---------- cada pin es el commit correcto del mirror ----------
# uses esperado → ref cuyo commit hay que fijar
declare -A WANT=(
  [actions/checkout]=v4 [actions/setup-python]=v5 [acme/lint]=v2
  [acme/workflows/.github/workflows/release.yml]=main [acme/tool]=v1.3.0
)
for u in "${!WANT[@]}"; do
  repo=$(cut -d/ -f1-2 <<<"$u")
  want=$(git -C "$G/$repo.git" rev-parse "${WANT[$u]}^{commit}")
  line=$(grep -E "^[[:space:]]*(-[[:space:]]*)?uses:[[:space:]]*['\"]?$u@" "$wf" | head -1)
  sha=$(sed -nE "s|.*$u@([0-9a-fA-F]+).*|\1|p" <<<"$line")
  if [ -z "$line" ]; then
    no "$u ya no está en el workflow."
  elif ! [[ "$sha" =~ ^[0-9a-f]{40}$ ]]; then
    no "$u sigue con ref flotante: $(sed -E 's/^[[:space:]-]*uses:[[:space:]]*//' <<<"$line")"
  elif [ "$sha" = "$want" ]; then
    if grep -qE '#[[:space:]]*v?[0-9A-Za-z.]+' <<<"$line"; then ok "$u → ${want:0:12}… (${WANT[$u]}) con comentario de versión."
    else no "$u bien fijado, pero sin '# <versión>' al final: nadie sabrá qué es ese SHA."; fi
  elif [ "$(git -C "$G/$repo.git" cat-file -t "$sha" 2>/dev/null)" = tag ]; then
    no "$u apunta al objeto *tag* anotado, no al commit (usa ^{commit})."
  elif [ "$u" = acme/tool ] && [ "$sha" = "$(git -C "$G/$repo.git" rev-parse 'v1^{commit}')" ]; then
    no "acme/tool fijado al commit comprometido (v1/v1.3.1). Lee SECURITY-ADVISORY.md."
  elif [ "$(git -C "$G/$repo.git" cat-file -t "$sha" 2>/dev/null)" = commit ]; then
    no "$u fijado a un commit real, pero no al de ${WANT[$u]}."
  else
    no "$u fijado a '$sha', que no existe en $G/$repo.git."
  fi
done

grep -qE '^[[:space:]]*-[[:space:]]*uses:[[:space:]]*\./\.github/actions/local-setup' "$wf" \
  && ok "La acción local sigue en el workflow." || no "Falta la acción local ./.github/actions/local-setup."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Actions fijadas a commits verificados. ¡Lab 96 resuelto!"; exit 0; } || exit 1
