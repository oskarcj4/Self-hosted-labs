#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
mkdir -p /var/crash && mv /srv/app/uploads/core.tienda.4127 /var/crash/
sed -i 's/^shared_buffers = 256MBB/shared_buffers = 256MB/' /etc/postgresql/15/main/conf.d/50-tuning.conf
systemctl restart postgresql@15-main
echo '127.0.0.1 db.interno' >> /etc/hosts
cat > /home/analista/postmortem.md <<'EOF'
# Postmortem — Game day app-05

## Resumen
503 en la tienda por tres fallos: volumen de subidas lleno por un core dump,
PostgreSQL caído por la errata shared_buffers = 256MBB (CHG-7301) y el alias
db.interno ausente de /etc/hosts.

## Cronología
- 10:02 /health 503.
- 10:08 core dump movido a /var/crash.
- 10:12 shared_buffers corregido a 256MB; postgresql@15-main reiniciado.
- 10:20 alias db.interno restaurado. 10:22 /health 200.

## Impacto
~20 min sin tienda. Sin pérdida de datos.

## Causa raíz
Core dump en el directorio de la app; cambio de config sin validar; /etc/hosts
regenerado fuera del aprovisionamiento.

## Acciones
- core_pattern fuera de /srv.
- Validar la config de PostgreSQL en CI.
- /etc/hosts gestionado por el aprovisionamiento.
EOF
chown analista:analista /home/analista/postmortem.md
sleep 1
