#!/usr/bin/env bash
# Lab 77 (ci-01): hay que instalar kvtool desde el mirror interno. El mirror
# está comprometido (ver setup-node/node.sh).
set -e
B=http://artifacts.interno/__lab
for _ in $(seq 1 60); do curl -fs $B/fingerprint >/dev/null && break; sleep 1; done
FPR=$(curl -fs $B/fingerprint)
mkdir -p /var/lib/tclab && chmod 0700 /var/lib/tclab
curl -fs $B/legit-1.4.1.sha > /var/lib/tclab/legit-1.4.1.sha
# Huella en grupos de 4, como la publica el fabricante en su web.
PRETTY=$(echo "$FPR" | sed 's/.\{4\}/& /g; s/ $//')

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/CHG-7702.txt <<EOF
CHG-7702 · ci-01 · instalar kvtool en el runner de CI
- Instalar kvtool en /usr/local/bin/kvtool desde el mirror interno:
    http://artifacts.interno/kvtool/
  (cada versión tiene su tar.gz, SHA256SUMS y SHA256SUMS.asc; las claves
   del fabricante están en KEYS.asc)
- Seguridad (SEC-7650): el mirror ha tenido un acceso no autorizado esta
  semana. NO te fíes de lo que sirve: verifica la firma con la clave del
  fabricante. Su huella, tal como la publica en su web (canal independiente):

    Kvtool Release <release@kvtool.example>
    $PRETTY

- Instala la versión más reciente que sea AUTÉNTICA.
- Deja un instalador reutilizable para el pipeline:
    /usr/local/bin/install-tool.sh <versión>
  * Mirror: \${ARTIFACTS_URL:-http://artifacts.interno/kvtool}
  * Verifica la firma de SHA256SUMS sólo contra la clave del fabricante
    (fijada en el runner; no la que diga el mirror) y el SHA-256 del tar.gz.
  * Si algo no cuadra: termina con error y NO toca el kvtool instalado.
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 77 plantado."
