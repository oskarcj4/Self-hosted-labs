#!/usr/bin/env bash
# Planta el escenario (root): banderas, documentos, config editable por analista
# y arranque del visor como 'svc'.
set -e
gen(){ echo "TCLAB{$(head -c16 /dev/urandom | od -An -tx1 | tr -d ' \n')}"; }
USER_FLAG=$(gen); ROOT_FLAG=$(gen)

install -d -o svc -g svc /srv/app /srv/docs /srv/private
cat > /srv/app/secrets.json <<EOF
{"user_flag":"$USER_FLAG","root_flag":"$ROOT_FLAG"}
EOF
chown svc:svc /srv/app/secrets.json; chmod 600 /srv/app/secrets.json

# Documento legítimo (descargable) y fichero privado fuera de /srv/docs.
cat > /srv/docs/readme.txt <<'EOF'
docs.lab - documentos publicos. Usa /download?file=readme.txt
EOF
printf '%s\n' "$USER_FLAG" > /srv/private/user.flag
chown -R svc:svc /srv/docs /srv/private
chmod 644 /srv/docs/readme.txt /srv/private/user.flag

# Config editable en modo blue: sin saneado de ruta y confiando en X-Admin.
install -d -o analista -g analista /etc/panel
cat > /etc/panel/config.json <<'EOF'
{
  "sanitize_path": false,
  "trust_admin_header": true
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
echo "visor recargado"
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
