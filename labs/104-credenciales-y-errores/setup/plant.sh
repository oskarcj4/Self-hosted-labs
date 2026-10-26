#!/usr/bin/env bash
# Planta el escenario (corre como root): banderas, config editable por analista
# (modo blue) y arranque del panel como 'svc'.
set -e
gen(){ echo "TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"; }
USER_FLAG=$(gen); ROOT_FLAG=$(gen)

install -d -o svc -g svc /srv/app
cat > /srv/app/secrets.json <<EOF
{"user_flag":"$USER_FLAG","root_flag":"$ROOT_FLAG"}
EOF
chown svc:svc /srv/app/secrets.json; chmod 600 /srv/app/secrets.json

# Config editable en modo blue: contraseña por defecto débil + errores verbosos.
install -d -o analista -g analista /etc/panel
cat > /etc/panel/config.json <<'EOF'
{
  "panel_pass": "admin",
  "verbose_errors": true
}
EOF
chown analista:analista /etc/panel/config.json; chmod 664 /etc/panel/config.json

cp /opt/lab/setup/app.py /srv/app/app.py; chmod 644 /srv/app/app.py
printf 'USER=%s\nROOT=%s\n' "$USER_FLAG" "$ROOT_FLAG" > /opt/lab/.flags
chmod 600 /opt/lab/.flags

pkill -f "/srv/app/app.py" 2>/dev/null || true
nohup runuser -u svc -- python3 /srv/app/app.py >/tmp/app.log 2>&1 &

cat > /usr/local/bin/app-apply <<'EOF'
#!/bin/sh
pkill -f "/srv/app/app.py" 2>/dev/null
sleep 1
nohup runuser -u svc -- python3 /srv/app/app.py >/tmp/app.log 2>&1 &
echo "panel recargado"
EOF
chmod 0755 /usr/local/bin/app-apply
cat > /usr/local/bin/app-reload <<'EOF'
#!/bin/sh
sudo /usr/local/bin/app-apply
EOF
chmod 0755 /usr/local/bin/app-reload
echo 'analista ALL=(root) NOPASSWD: /usr/local/bin/app-apply' > /etc/sudoers.d/analista
chmod 440 /etc/sudoers.d/analista
sleep 1
echo "escenario listo (modo ${TCLAB_MODE:-blue})."
