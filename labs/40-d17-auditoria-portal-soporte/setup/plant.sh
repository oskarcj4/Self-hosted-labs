#!/usr/bin/env bash
# Lab 40 (Día 17): un contenedor lanzado a mano con "docker run" que no se
# parece en nada a las notas de traspaso.
set -e
P=/home/analista/support
mkdir -p "$P" /home/analista/audit /srv/support/uploads
cp -r /opt/lab/setup/project/. "$P/"
docker build -q -t support/portal:2.3.1 "$P/portal"
for i in 1 2 3; do echo "adjunto $i" > /srv/support/uploads/ticket-10$i.txt; done

docker run -d --name support-portal --restart unless-stopped \
  -p 8088:8000 \
  -v /srv/support/uploads:/app/uploads \
  -e SUPPORT_SMTP_PASSWORD='smtp-Supp0rt-2026!' \
  -e SUPPORT_SMTP_HOST=smtp.interno.example \
  support/portal:2.3.1 >/dev/null
docker inspect -f '{{.Id}}' support-portal > /root/.tclab-portal.id

chown -R analista:analista "$P" /home/analista/audit
echo "Lab 40 plantado."
