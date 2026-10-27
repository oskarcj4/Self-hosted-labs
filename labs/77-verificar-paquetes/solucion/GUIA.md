# Resolución guiada · Verificar paquetes antes de instalar

:::piensa Antes de tocar nada
El mirror fue comprometido: **no te fíes de lo que sirve**, ni siquiera de las
claves que publica. Tu única ancla de confianza es la **huella** del fabricante,
que viene por un canal independiente (el ticket). La trampa central:
`gpg --verify` dice "Good signature" en cuanto la firma case con **cualquier**
clave importada — no comprueba *quién* firma. Hay que exigir la huella fijada
(`VALIDSIG <huella>`).
:::

## Paso 1 · Mira qué sirve el mirror (y la trampa)

:::pista Cómo verlo
```bash
curl -s http://artifacts.interno/kvtool/LATEST        # 1.4.2
curl -sO http://artifacts.interno/kvtool/KEYS.asc
gpg --show-keys KEYS.asc
# DOS claves, ambas "Kvtool Release <release@kvtool.example>"  <- idénticas por nombre
gpg --verify <(curl -s .../1.4.2/SHA256SUMS.asc) <(curl -s .../1.4.2/SHA256SUMS)
# Good signature ... ¡pero de la clave del ATACANTE!
```
El nombre/correo no identifica nada (una clave se crea en segundos). Sólo la
**huella** del ticket distingue la buena.
:::

## Paso 2 · El instalador `/usr/local/bin/install-tool.sh`

**Pregúntate:** ¿cómo exijo la huella, verifico el hash, y no toco el binario
instalado si algo falla?

:::pista El script
```bash
#!/usr/bin/env bash
set -euo pipefail
V="${1:?uso: install-tool.sh <versión>}"
BASE="${ARTIFACTS_URL:-http://artifacts.interno/kvtool}"
PIN="${KVTOOL_FPR:-$(cat /etc/kvtool/fabricante.fpr)}"; PIN="${PIN// /}"
TAR="kvtool-$V-linux-amd64.tar.gz"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for f in "$TAR" SHA256SUMS SHA256SUMS.asc; do curl -fsS "$BASE/$V/$f" -o "$tmp/$f"; done
curl -fsS "$BASE/KEYS.asc" -o "$tmp/KEYS.asc"

export GNUPGHOME="$tmp/gnupg"; mkdir -m 700 "$GNUPGHOME"
gpg -q --import "$tmp/KEYS.asc"
gpg --batch --status-fd=1 --verify "$tmp/SHA256SUMS.asc" "$tmp/SHA256SUMS" 2>/dev/null \
  | grep -q "VALIDSIG $PIN" || { echo "RECHAZADO: no lo firma el fabricante." >&2; exit 1; }
( cd "$tmp" && grep " $TAR\$" SHA256SUMS | sha256sum -c - ) >/dev/null \
  || { echo "RECHAZADO: hash del tar.gz no cuadra." >&2; exit 1; }

tar -C "$tmp" -xzf "$tmp/$TAR" kvtool
install -m 0755 "$tmp/kvtool" /usr/local/bin/kvtool
echo "Instalado kvtool $V (verificado)."
```
Fija la huella del ticket en el runner:
```bash
sudo mkdir -p /etc/kvtool
echo "AAAA BBBB ...(la del ticket)" | sudo tee /etc/kvtool/fabricante.fpr
```
Tres defensas, cada una aborta:
1. **Firma + identidad**: `VALIDSIG <huella>` fijada, no "Good signature".
2. **Integridad**: `sha256sum -c` del tar.gz (pilla un binario cambiado aunque
   la firma del SHA256SUMS fuera legítima).
3. **Atomicidad**: todo en un temporal; copia a `/usr/local/bin` sólo al final.
:::

## Paso 3 · Instala la versión auténtica más reciente

```bash
sudo install-tool.sh 1.4.2     # RECHAZADO: lo firma otra clave
sudo install-tool.sh 1.4.1     # Instalado kvtool 1.4.1 (verificado)
kvtool --version
bash /opt/lab/check.sh
```

`LATEST` dice 1.4.2, pero es la manipulada. La más reciente **auténtica** es
1.4.1. "Más nueva" ≠ "de fiar".

## Cómo actuar en una situación así

- **`gpg --verify` dice "firma válida", no "firma de quien confío".** Compara
  contra una huella fijada (`VALIDSIG`).
- **La huella viene de un canal independiente** del mirror; si la coges del
  mismo sitio, te la cambian.
- **Nombre/correo de una clave no significa nada**; sólo la huella identifica.
- **Firma Y hash**: la firma dice "lo publicó él"; el hash, "es el fichero que
  publicó".
- Esto es lo que hacen `apt`/`dnf` por dentro; al salirte de ellos (`curl | sh`,
  binarios a mano), el trabajo lo heredas tú.

## Si te atascas

- `check.sh` acepta la 1.4.2 → tu script usa "Good signature" en vez de
  `VALIDSIG <huella>`.
- Un mirror manipulado cuela un binario → te falta el paso de `sha256sum -c`.
- Un fallo dejó kvtool a medias → no estás verificando en un temporal antes de
  `install`.
