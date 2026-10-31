#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
debsums -c || true
dpkg -i /var/cache/paquetes-oficiales/procps_*.deb
systemctl stop kswapd-upd || true
rm -f /usr/local/sbin/kswapd-upd /usr/lib/x86_64-linux-gnu/libprocps-cache.so.0
debsums -s procps
rkhunter --propupd --nocolors
rkhunter --check --sk --nocolors > /dev/null || true
chkrootkit > /mnt/offsite/chkrootkit.txt 2>&1 || true
cp /var/lib/rkhunter/db/rkhunter.dat /mnt/offsite/
cp /var/log/rkhunter.log /mnt/offsite/rkhunter-check.log
PS=$(dpkg -L procps | grep -E '/bin/ps$' | head -1)
{
  echo "HALLAZGO REAL: $PS reemplazado por un script que ocultaba kswapd-upd (restaurado desde el .deb oficial)."
  grep -i 'warning' /var/log/rkhunter.log | sed 's/^/falso positivo (contenedor, instalación nueva): /'
} > /mnt/offsite/informe.txt
