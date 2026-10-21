# Solución — Verificar paquetes antes de instalar

## 1. Mirar qué sirve el mirror

```bash
curl -s http://artifacts.interno/kvtool/
curl -s http://artifacts.interno/kvtool/LATEST        # 1.4.2
curl -sO http://artifacts.interno/kvtool/KEYS.asc
gpg --show-keys KEYS.asc
```

`KEYS.asc` trae **dos** claves, las dos con el nombre
`Kvtool Release <release@kvtool.example>`. Una es la del fabricante; la otra,
la que metió el atacante. Por el nombre son idénticas: sólo las distingue la
**huella**. La del ticket (canal independiente) es la buena.

```bash
gpg --verify <(curl -s .../1.4.2/SHA256SUMS.asc) <(curl -s .../1.4.2/SHA256SUMS)
# gpg: Good signature ...        <- ¡pero firmada por la clave del ATACANTE!
```

Ahí está la trampa: `gpg --verify` dice "Good signature" en cuanto la firma
case con **cualquier** clave importada. No comprueba *quién* firma. Hay que
exigir la huella.

## 2. El instalador

`/usr/local/bin/install-tool.sh`:

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

Fija la huella del fabricante en el runner:

```bash
sudo mkdir -p /etc/kvtool
echo "AAAA BBBB ...(la del ticket)" | sudo tee /etc/kvtool/fabricante.fpr
```

Tres defensas en orden, y cada una puede abortar:

1. **Firma + identidad**: `VALIDSIG <huella>` con la huella fijada. No basta
   "Good signature". El `status-fd` da la huella completa de quien firmó, en
   formato máquina.
2. **Integridad**: `sha256sum -c` del tar.gz contra `SHA256SUMS`. Pilla un
   `tar.gz` cambiado aunque la firma del `SHA256SUMS` fuese legítima (p. ej.
   si sólo tocaron el binario).
3. **Atomicidad**: se descarga y verifica en un temporal; sólo se copia a
   `/usr/local/bin/kvtool` al final. Un fallo no deja a medias el binario en
   producción.

## 3. Instalar la versión auténtica más reciente

```bash
sudo install-tool.sh 1.4.2     # RECHAZADO: lo firma otra clave
sudo install-tool.sh 1.4.1     # Instalado kvtool 1.4.1 (verificado)
kvtool --version
```

`LATEST` dice `1.4.2`, pero es la manipulada. La más reciente **auténtica**
es la `1.4.1`. "Más nueva" no es lo mismo que "de fiar".

## Lecciones

- `gpg --verify` responde "firma válida", no "firma de quien yo confío".
  Compara siempre contra una **huella fijada** (`VALIDSIG`).
- La huella de confianza tiene que venir de un canal **independiente** del que
  sirve el paquete. Si la coges del mismo mirror, el atacante te la cambia.
- Un mismo nombre/correo en una clave no significa nada: las claves se crean
  en segundos. Sólo la huella identifica.
- Firma **y** hash: cosas distintas. La firma dice "lo publicó él"; el hash,
  "es el fichero que él publicó".
- Esto es lo que hacen por dentro `apt`/`dnf` con sus repos. Al salirte de un
  gestor de paquetes (binarios "a mano", `curl | sh`), el trabajo lo heredas tú.
