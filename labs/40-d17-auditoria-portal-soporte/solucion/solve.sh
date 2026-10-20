#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
C=support-portal
u=$(docker inspect -f '{{.Config.User}}' $C); [ -z "$u" ] && u=root
cat > /home/analista/audit/support-portal.txt <<EOF
imagen=$(docker inspect -f '{{.Config.Image}}' $C)
puerto_host=$(docker port $C 8000/tcp | head -1 | sed 's/.*://')
puerto_contenedor=8000
montaje_origen=$(docker inspect -f '{{range .Mounts}}{{.Source}}{{end}}' $C)
montaje_destino=$(docker inspect -f '{{range .Mounts}}{{.Destination}}{{end}}' $C)
montaje_modo=$(docker inspect -f '{{range .Mounts}}{{if .RW}}rw{{else}}ro{{end}}{{end}}' $C)
usuario=$u
secretos_env=SUPPORT_SMTP_PASSWORD,ZENDESK_API_TOKEN
EOF
chown analista: /home/analista/audit/support-portal.txt
