#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
H=/home/analista
as(){ sudo -u analista -H bash -lc "$1"; }

# 1) Importar clave y verificar la copia entregada (debe fallar)
as 'gpg --import /opt/entrega/vendor.pub >/dev/null 2>&1 || true'
as 'cd /opt/entrega && sha256sum -c SHA256SUMS 2>&1 | tail -1 || true'
as 'cd /opt/entrega && gpg --verify instalador.sh.asc instalador.sh 2>&1 | grep -i signature || true'

# 2) Veredicto
WANT=$(sha256sum /srv/mirror/instalador.sh | cut -d' ' -f1)
as "cat > ~/veredicto.txt <<V
entregado_integro=no
firma_valida=no
sha_correcto=$WANT
V"

# 3) Ejecutar el instalador LEGÍTIMO en sandbox sin red
as 'bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --bind ~/instalado /mnt --unshare-net env DESTINO=/mnt bash /srv/mirror/instalador.sh > ~/salida-sandbox.txt 2>&1'
echo "solve.sh completado. sha_correcto=$WANT"
cat $H/salida-sandbox.txt
