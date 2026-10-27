#!/usr/bin/env bash
set -e
P=/home/analista/release
cat > "$P/sbom-gen.sh" <<'EOF'
#!/usr/bin/env bash
# Inventario de la imagen del release, sacado de la propia imagen.
# Uso: ./sbom-gen.sh [imagen]   (por defecto shop/rel:1.0)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
img="${1:-shop/rel:1.0}"
id=$(docker image inspect -f '{{.Id}}' "$img")
docker run --rm --network none --entrypoint apk "$img" info -v 2>/dev/null | sort \
  | jq -R . | jq -s --arg img "$img" --arg id "$id" \
      '{image: $img, id: $id, packages: .}' > dist/sbom.json
echo "SBOM escrito en dist/sbom.json ($(jq '.packages | length' dist/sbom.json) paquetes)"
EOF
cat > "$P/verify.sh" <<'EOF'
#!/usr/bin/env bash
# Gate de release: firma de la clave de confianza + SBOM atado a la imagen.
# Uso: ./verify.sh [imagen]   (por defecto shop/rel:1.0)
set -euo pipefail
cd "$(dirname "$0")"
img="${1:-shop/rel:1.0}"
TRUST=/etc/release/trusted.pub
openssl dgst -sha256 -verify "$TRUST" -signature dist/sbom.json.sig dist/sbom.json >/dev/null \
  || { echo "FAIL: la firma no es de la clave de confianza"; exit 1; }
want=$(docker image inspect -f '{{.Id}}' "$img")
got=$(jq -r .id dist/sbom.json)
[ "$got" = "$want" ] || { echo "FAIL: el SBOM describe $got, no $img ($want)"; exit 1; }
echo "OK: release $img verificado"
EOF
rm -f "$P/keys/sbom.pub"
chmod 0755 "$P/sbom-gen.sh" "$P/verify.sh"
chown -R analista:analista "$P"
su -s /bin/bash analista -c "cd '$P' && ./sbom-gen.sh \
  && openssl dgst -sha256 -sign ~/.signing/release.key -out dist/sbom.json.sig dist/sbom.json \
  && ./verify.sh"
