#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
IMG=localhost:5000/hola:1.0
T=$(mktemp -d)

echo "== Lab 184 · Imágenes multiarquitectura — comprobación =="

RAW=$(docker buildx imagetools inspect --raw "$IMG" 2>/dev/null)
PL=$(echo "$RAW" | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(' '.join(sorted(f\"{m['platform']['os']}/{m['platform']['architecture']}\" for m in d.get('manifests', [])
      if m.get('platform', {}).get('os') != 'unknown')))" 2>/dev/null)
if [ "$PL" = "linux/amd64 linux/arm64" ]; then
  ok "$IMG es un índice con linux/amd64 y linux/arm64."
else
  no "$IMG: plataformas publicadas '${PL:-ninguna (¿no existe o no es multiplataforma?)}', se esperan linux/amd64 y linux/arm64."
fi

# Saca /hola de cada variante y lee la arquitectura de la cabecera ELF.
elf(){ python3 - "$1" <<'PY'
import sys
b = open(sys.argv[1], "rb").read(64)
if b[:4] != b"\x7fELF":
    print("no-ELF"); sys.exit()
m = int.from_bytes(b[18:20], "little")
print({0x3E: "amd64", 0xB7: "arm64", 0x03: "386", 0x28: "arm"}.get(m, hex(m)))
PY
}
BIEN=0; DET=""
for a in amd64 arm64; do
  d=$T/$a; mkdir -p $d/fs
  if skopeo copy -q --src-tls-verify=false --override-os linux --override-arch $a "docker://$IMG" "dir:$d/img" 2>/dev/null; then
    for l in $(python3 -c "import json;print(' '.join(x['digest'].split(':')[1] for x in json.load(open('$d/img/manifest.json'))['layers']))"); do
      tar -xf "$d/img/$l" -C $d/fs 2>/dev/null || tar -xzf "$d/img/$l" -C $d/fs 2>/dev/null
    done
    BIN=$(find $d/fs -maxdepth 2 -type f -name hola | head -1)
    ARQ=$([ -n "$BIN" ] && elf "$BIN" || echo "sin /hola")
    [ "$ARQ" = "$a" ] && BIEN=$((BIEN+1))
    DET="$DET $a→$ARQ"
  else
    DET="$DET $a→(no se puede descargar)"
  fi
done
if [ "$BIEN" = 2 ]; then
  ok "Cada variante lleva el binario de su arquitectura:$DET."
else
  no "Binario por variante:$DET (cada una debe llevar el suyo)."
fi

OUT=$(docker run --rm --pull always "$IMG" 2>/dev/null)
if [ "$OUT" = "hola 1.0 desde linux/amd64" ]; then
  ok "En amd64 la imagen ejecuta: '$OUT'."
else
  no "docker run $IMG en amd64 dice '${OUT:-nada}' (esperado 'hola 1.0 desde linux/amd64')."
fi

DF=/home/analista/hola/Dockerfile
if grep -qE '^\s*ARG\s+.*TARGET(OS|ARCH)' $DF && grep -qE 'GOARCH=\$\{?TARGETARCH' $DF && grep -q 'BUILDPLATFORM' $DF; then
  ok "Dockerfile: compila en \$BUILDPLATFORM para \$TARGETOS/\$TARGETARCH."
else
  no "Dockerfile: FROM --platform=\$BUILDPLATFORM, ARG TARGETOS TARGETARCH y GOOS/GOARCH en el go build."
fi
rm -rf "$T"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Una etiqueta, dos arquitecturas, cero emulación."; exit 0; } || exit 1
