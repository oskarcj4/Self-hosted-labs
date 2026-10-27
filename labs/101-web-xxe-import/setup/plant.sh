#!/usr/bin/env bash
# Planta el Lab 101. Corre como root (desde CMD).
set -e
A=/srv/app
install -o app -g app -d "$A"
cp /opt/lab/setup/app/app.py "$A/"
chown analista:analista "$A/app.py"; chmod 644 "$A/app.py"

FLAG="TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
printf '%s' "$FLAG" > "$A/flag.txt"        # sin salto: entidad lo lee limpio
chown app:app "$A/flag.txt"; chmod 600 "$A/flag.txt"
printf '%s' "$FLAG" > /opt/lab/.flag; chmod 600 /opt/lab/.flag

: > "$A/reload"; chmod 666 "$A/reload"; chown app:app "$A/reload"
install -m 0755 /opt/lab/setup/supervisor.sh /usr/local/bin/app-supervisor
printf '#!/bin/sh\ntouch /srv/app/reload && echo "app recargada (espera ~2s)"\n' > /usr/local/bin/app-reload
printf '#!/bin/sh\ntail -n "${1:-20}" /tmp/app.log\n' > /usr/local/bin/app-logs
chmod 0755 /usr/local/bin/app-reload /usr/local/bin/app-logs

nohup runuser -u app -- bash /usr/local/bin/app-supervisor >/tmp/supervisor.log 2>&1 &
for _ in $(seq 1 20); do curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1 && break; sleep 0.5; done
echo "Lab 101 plantado."
