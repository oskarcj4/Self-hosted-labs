#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root en ci-01.
set -e
# La huella del fabricante. En el lab real se saca del ticket (canal
# independiente); aquí, del fichero que dejó el plant.
FPR=$(curl -fs http://artifacts.interno/__lab/fingerprint)

install -m 0755 /dev/stdin /usr/local/bin/install-tool.sh <<'SCRIPT'
#!/usr/bin/env bash
# install-tool.sh <versión> — instala kvtool verificando firma y hash.
set -euo pipefail
V="${1:?uso: install-tool.sh <versión>}"
BASE="${ARTIFACTS_URL:-http://artifacts.interno/kvtool}"
# Huella del fabricante, FIJADA en el runner (no se toma del mirror).
PIN="${KVTOOL_FPR:-$(cat /etc/kvtool/fabricante.fpr)}"
PIN="${PIN// /}"
TAR="kvtool-$V-linux-amd64.tar.gz"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for f in "$TAR" SHA256SUMS SHA256SUMS.asc; do
  curl -fsS "$BASE/$V/$f" -o "$tmp/$f"
done
curl -fsS "$BASE/KEYS.asc" -o "$tmp/KEYS.asc"

export GNUPGHOME="$tmp/gnupg"; mkdir -m 700 "$GNUPGHOME"
gpg -q --import "$tmp/KEYS.asc"
# Verifica la firma y EXIGE que la firme la huella fijada.
if ! gpg --batch --status-fd=1 --verify "$tmp/SHA256SUMS.asc" "$tmp/SHA256SUMS" 2>/dev/null \
      | grep -q "VALIDSIG $PIN"; then
  echo "RECHAZADO: SHA256SUMS no está firmado por la clave del fabricante ($PIN)." >&2
  exit 1
fi
# Verifica el hash del tar.gz contra SHA256SUMS.
( cd "$tmp" && grep " $TAR\$" SHA256SUMS | sha256sum -c - ) >/dev/null 2>&1 || {
  echo "RECHAZADO: el SHA-256 de $TAR no coincide con SHA256SUMS." >&2; exit 1; }

tar -C "$tmp" -xzf "$tmp/$TAR" kvtool
install -m 0755 "$tmp/kvtool" /usr/local/bin/kvtool
echo "Instalado kvtool $V (verificado)."
SCRIPT

mkdir -p /etc/kvtool; echo "$FPR" > /etc/kvtool/fabricante.fpr; chmod 0644 /etc/kvtool/fabricante.fpr

# LATEST dice 1.4.2, pero ese está firmado por el atacante: install-tool lo rechaza.
install-tool.sh "$(curl -fs http://artifacts.interno/kvtool/LATEST)" || true
# La versión más reciente AUTÉNTICA es la 1.4.1.
install-tool.sh 1.4.1
kvtool --version
