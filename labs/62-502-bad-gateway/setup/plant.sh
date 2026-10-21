#!/usr/bin/env bash
# Lab 62: tras el despliegue de la v2 de 'gestion', nginx devuelve 502 en la
# app, 403 en los estáticos y 504 en el informe.
set -e
id gestion >/dev/null 2>&1 || useradd -r -s /usr/sbin/nologin gestion
install -m 0755 /opt/lab/setup/gestion.py /usr/local/lib/gestion.py
mkdir -p /etc/gestion
cat > /etc/gestion/gestion.env <<'EOF'
# v2 (DEPLOY-912): el puerto pasa de 8000 a 8001 para convivir con el agente de métricas.
PORT=8001
EOF
cat > /etc/systemd/system/gestion.service <<'EOF'
[Unit]
Description=gestion (app interna)
After=network.target

[Service]
User=gestion
EnvironmentFile=/etc/gestion/gestion.env
ExecStart=/usr/bin/python3 /usr/local/lib/gestion.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Estáticos copiados por el pipeline como root con umask 077.
mkdir -p /srv/gestion/static
echo "logo-gestion-v2" > /srv/gestion/static/logo.txt
echo "body{font-family:sans-serif}" > /srv/gestion/static/app.css
chown -R root:root /srv/gestion
chmod 0700 /srv/gestion/static
chmod 0600 /srv/gestion/static/*

rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/gestion <<'EOF'
upstream gestion_app {
    server 127.0.0.1:8000;
}

server {
    listen 80 default_server;
    server_name gestion.local;

    location /static/ {
        alias /srv/gestion/static/;
    }

    location / {
        proxy_pass http://gestion_app;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_connect_timeout 3s;
        proxy_read_timeout 5s;
    }
}
EOF
ln -sf /etc/nginx/sites-available/gestion /etc/nginx/sites-enabled/gestion
systemctl daemon-reload
systemctl enable --now gestion nginx

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/INC-6202.txt <<'EOF'
INC-6202 · gestion-01 · tras DEPLOY-912 (gestion v2)
- http://gestion-01/            -> 502 Bad Gateway
- http://gestion-01/static/...  -> 403 Forbidden
- http://gestion-01/api/informe -> 502 ahora; en staging, con la v2, daba
  504 Gateway Time-out (el informe tarda ~12 s en generarse; siempre ha sido así)
Desarrollo: "en la v2 sólo cambiamos el puerto, está en el changelog".
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 62 plantado."
