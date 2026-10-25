#!/usr/bin/env bash
# Planta el escenario del Lab 97. Corre como root (desde CMD).
set -e
A=/srv/app
install -o app -g app -d "$A"
cp /opt/lab/setup/app/app.py /opt/lab/setup/app/init_db.py "$A/"
chown app:app "$A/app.py" "$A/init_db.py"

# Flag aleatoria por build. Canónica en /opt/lab/.flag (solo root / el check).
FLAG="TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"
printf '%s' "$FLAG" > /opt/lab/.flag
chmod 600 /opt/lab/.flag
ADMIN_PW="$(head -c12 /dev/urandom | od -An -tx1 | tr -d ' \n')"

# DB creada por 'app': queda 600 app:app. analista no puede leerla.
FLAG="$FLAG" ADMIN_PW="$ADMIN_PW" runuser -u app -- python3 "$A/init_db.py"
chmod 600 "$A/app.db"

# Código de la app: editable por analista (para arreglarlo), no borrable (dir es de app).
chown analista:analista "$A/app.py"
chmod 644 "$A/app.py"

# Gancho de recarga y supervisor.
: > "$A/reload"; chmod 666 "$A/reload"; chown app:app "$A/reload"
install -m 0755 /opt/lab/setup/supervisor.sh /usr/local/bin/app-supervisor
printf '#!/bin/sh\ntouch /srv/app/reload && echo "app recargada (espera ~2s)"\n' > /usr/local/bin/app-reload
printf '#!/bin/sh\ntail -n "${1:-20}" /tmp/app.log\n' > /usr/local/bin/app-logs
chmod 0755 /usr/local/bin/app-reload /usr/local/bin/app-logs

nohup runuser -u app -- bash /usr/local/bin/app-supervisor >/tmp/supervisor.log 2>&1 &
for _ in $(seq 1 20); do curl -fsS http://127.0.0.1:8080/ >/dev/null 2>&1 && break; sleep 0.5; done
echo "Lab 97 plantado."
