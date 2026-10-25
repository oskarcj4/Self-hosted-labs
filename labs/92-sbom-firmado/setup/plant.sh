#!/usr/bin/env bash
set -e
P=/home/analista/release
mkdir -p "$P/dist" "$P/keys" /etc/release /home/analista/.signing
cp -r /opt/lab/setup/project/. "$P/"
chmod 0755 "$P/sbom-gen.sh" "$P/verify.sh"

# Clave de firma real del release: fuera del repo. Ancla de confianza: root.
openssl genrsa -out /home/analista/.signing/release.key 2048 >/dev/null 2>&1
openssl rsa -in /home/analista/.signing/release.key -pubout \
  -out /etc/release/trusted.pub >/dev/null 2>&1
chmod 700 /home/analista/.signing
chmod 600 /home/analista/.signing/release.key
chown root:root /etc/release/trusted.pub
chmod 644 /etc/release/trusted.pub

cd "$P"
docker build -q -t shop/rel:1.0 ./api >/dev/null

# PR #214 "rotar clave de SBOM": cambia keys/sbom.pub y sube un SBOM firmado
# con SU clave. El verify.sh actual se lo traga.
A=$(mktemp -d)
openssl genrsa -out "$A/k" 2048 >/dev/null 2>&1
openssl rsa -in "$A/k" -pubout -out "$P/keys/sbom.pub" >/dev/null 2>&1
printf '{"image":"shop/rel:1.0","id":"sha256:%064d","packages":["python==3.12"]}\n' 0 \
  > "$P/dist/sbom.json"
openssl dgst -sha256 -sign "$A/k" -out "$P/dist/sbom.json.sig" "$P/dist/sbom.json"
rm -rf "$A"

chown -R analista:analista "$P" /home/analista/.signing
echo "Lab 92 plantado."
