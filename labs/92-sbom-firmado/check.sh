#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/release
TRUST=/etc/release/trusted.pub
T=$(mktemp -d /tmp/rt92.XXXXXX)
cleanup(){ docker image rm -f shop/rel:evil >/dev/null 2>&1; rm -rf "$T"; }

echo "== Lab 92 · SBOM firmado — comprobación =="

id=$(docker image inspect -f '{{.Id}}' shop/rel:1.0 2>/dev/null || true)
S="$P/dist/sbom.json"

# ---------- contenido del SBOM ----------
if [ -f "$S" ] && [ "$(jq -r .id "$S" 2>/dev/null)" = "$id" ]; then
  ok "dist/sbom.json describe shop/rel:1.0 ($id)."
else
  no "dist/sbom.json no describe el id actual de shop/rel:1.0."
fi

docker run --rm --network none --entrypoint apk shop/rel:1.0 info -v 2>/dev/null | sort > "$T/real"
jq -r '.packages[]?' "$S" 2>/dev/null | sort > "$T/decl"
if [ -s "$T/real" ] && cmp -s "$T/real" "$T/decl"; then
  ok "packages = apk info -v de la imagen ($(wc -l < "$T/real") paquetes)."
else
  no "packages no coincide con apk info -v de la imagen (faltan $(comm -23 "$T/real" "$T/decl" | wc -l), sobran $(comm -13 "$T/real" "$T/decl" | wc -l))."
fi

# ---------- firma genuina ----------
if [ -f "$S" ] && [ -f "$S.sig" ] && openssl dgst -sha256 -verify "$TRUST" -signature "$S.sig" "$S" >/dev/null 2>&1; then
  ok "La firma verifica contra /etc/release/trusted.pub."
else
  no "dist/sbom.json.sig no verifica contra la clave de confianza."
fi

if (cd "$P" && ./verify.sh) >"$T/v.out" 2>&1; then
  ok "./verify.sh acepta el release genuino."
else
  no "./verify.sh falla con el release genuino:"; sed 's/^/      /' "$T/v.out"
fi

# ---------- ataques ----------
# A1: SBOM firmado con otra clave, que además se cuela como keys/sbom.pub.
cp -r "$P" "$T/a1"
openssl genrsa -out "$T/evil.key" 2048 >/dev/null 2>&1
openssl rsa -in "$T/evil.key" -pubout -out "$T/a1/keys/sbom.pub" >/dev/null 2>&1
jq '.packages += ["backdoor-1.0-r0"]' "$S" > "$T/a1/dist/sbom.json" 2>/dev/null
openssl dgst -sha256 -sign "$T/evil.key" -out "$T/a1/dist/sbom.json.sig" "$T/a1/dist/sbom.json"
if (cd "$T/a1" && ./verify.sh) >/dev/null 2>&1; then
  no "verify.sh acepta un SBOM firmado con la clave del atacante."
else
  ok "verify.sh rechaza la firma de una clave no confiable."
fi

# A2: SBOM genuino alterado después de firmar.
cp -r "$P" "$T/a2"
jq '.packages += ["backdoor-1.0-r0"]' "$S" > "$T/a2/dist/sbom.json" 2>/dev/null
if (cd "$T/a2" && ./verify.sh) >/dev/null 2>&1; then
  no "verify.sh acepta un SBOM modificado tras la firma."
else
  ok "verify.sh rechaza un SBOM alterado."
fi

# A3: imagen sustituida; SBOM y firma genuinos, pero de otra imagen.
printf 'FROM shop/rel:1.0\nLABEL injected=1\n' | docker build -q -t shop/rel:evil - >/dev/null 2>&1
if (cd "$P" && ./verify.sh shop/rel:evil) >/dev/null 2>&1; then
  no "verify.sh shop/rel:evil pasa: el SBOM no está atado a la imagen."
else
  ok "verify.sh rechaza una imagen que no es la del SBOM."
fi

# ---------- higiene ----------
if grep -rlq 'PRIVATE KEY' "$P" 2>/dev/null; then
  no "Hay una clave privada dentro de ~/release: $(grep -rl 'PRIVATE KEY' "$P" | head -1)"
else
  ok "Ninguna clave privada dentro del repo."
fi
cleanup

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Release atado a imagen, inventario y clave de confianza. ¡Lab 92 resuelto!"; exit 0; } || exit 1
