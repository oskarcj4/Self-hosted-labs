#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
F=/etc/nginx/sites-available/gestion
sed -i 's/server 127.0.0.1:8000;/server 127.0.0.1:8001;/' $F
python3 - "$F" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("    location / {", """    location /api/informe {
        proxy_pass http://gestion_app;
        proxy_set_header Host $host;
        proxy_read_timeout 30s;
    }

    location / {""", 1)
open(p, "w").write(s)
PY
chmod 0755 /srv/gestion/static
chmod 0644 /srv/gestion/static/*
nginx -t
systemctl reload nginx
