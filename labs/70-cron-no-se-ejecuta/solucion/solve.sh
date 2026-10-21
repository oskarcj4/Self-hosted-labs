#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
cd /etc/cron.d
sed -i 's|^\* \* \* \* \* /usr/local/bin/limpieza-tmp.sh|* * * * * root /usr/local/bin/limpieza-tmp.sh|' limpieza-tmp
mv informe.diario informe-diario
sed -i 's| root metricas-push| root /usr/local/bin/metricas-push|' metricas
sed -i 's|date +%F|date +\\%F|' backup-db
echo >> sync-catalogo
chmod 0755 /usr/local/bin/sync-catalogo.sh
cat limpieza-tmp metricas backup-db sync-catalogo | grep -v '^#'
