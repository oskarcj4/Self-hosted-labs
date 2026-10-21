#!/usr/bin/env bash
# Lab 70: cinco tareas de cron que "están programadas" y no se ejecutan, cada
# una por un motivo distinto. En staging corren cada minuto para poder probar.
set -e
mkdir -p /var/lib/heartbeat
cat > /usr/local/bin/hb <<'EOF'
#!/bin/sh
# Latido: deja constancia de que una tarea ha corrido.
date '+%F %T' > "/var/lib/heartbeat/$1"
EOF
chmod 0755 /usr/local/bin/hb

mk(){ printf '#!/bin/bash\n# %s\n%s\n' "$2" "$3" > "$1"; chmod "${4:-0755}" "$1"; }
mk /usr/local/bin/limpieza-tmp.sh "Borra temporales de la app de más de 2 días." \
   'find /var/tmp/app -type f -mtime +2 -delete 2>/dev/null; /usr/local/bin/hb limpieza'
mk /usr/local/bin/informe-diario.sh "Genera el informe diario." \
   '/usr/local/bin/hb informe'
mk /usr/local/bin/metricas-push "Empuja métricas al colector." \
   '/usr/local/bin/hb metricas'
mk /usr/local/bin/backup-db.sh "Volcado de la BD (simulado)." \
   'echo "volcado OK $(date)"; /usr/local/bin/hb backup'
mk /usr/local/bin/sync-catalogo.sh "Sincroniza el catálogo con el ERP." \
   '/usr/local/bin/hb sync' 0644

# 1) Falta el campo de usuario (en /etc/cron.d es obligatorio).
cat > /etc/cron.d/limpieza-tmp <<'EOF'
# Limpieza de temporales
* * * * * /usr/local/bin/limpieza-tmp.sh
EOF
# 2) Nombre con punto: cron ignora los ficheros de /etc/cron.d con '.' en el nombre.
cat > /etc/cron.d/informe.diario <<'EOF'
# Informe diario
* * * * * root /usr/local/bin/informe-diario.sh
EOF
# 3) Comando sin ruta: el PATH de cron es /usr/bin:/bin.
cat > /etc/cron.d/metricas <<'EOF'
# Métricas
* * * * * root metricas-push
EOF
# 4) '%' sin escapar: para cron significa "salto de línea".
cat > /etc/cron.d/backup-db <<'EOF'
# Backup de la BD: un log por día
* * * * * root /usr/local/bin/backup-db.sh > /var/log/backup-db-$(date +%F).log 2>&1
EOF
# 5) Script sin permiso de ejecución y fichero sin salto de línea final.
printf '# Sincronización con el ERP\n* * * * * root /usr/local/bin/sync-catalogo.sh' > /etc/cron.d/sync-catalogo
chmod 0644 /etc/cron.d/*

systemctl enable --now cron

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/PROB-7010.txt <<'EOF'
PROB-7010 · cron-01 · "las tareas de cron no hacen nada"
- Hay 5 tareas en /etc/cron.d/. En staging corren cada minuto para probar.
- Cada tarea, cuando corre, deja un latido en /var/lib/heartbeat/<nombre>:
    limpieza  informe  metricas  backup  sync
  Ahora mismo no hay ni uno.
- backup-db debe dejar además su log diario: /var/log/backup-db-AAAA-MM-DD.log
- Lanzar los scripts a mano "funciona".
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 70 plantado."
