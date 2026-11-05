#!/usr/bin/env bash
# Lab 158: allsafe-api va a salir a producción, pero la revisión de go-live
# encuentra huecos: corre como root, el secreto es legible por todos, no hay
# backups, ni runbook, ni rollback. El alumno los cierra y firma el checklist.
set -e
install -d -m 0755 /opt/allsafe
useradd --system --no-create-home appuser 2>/dev/null || true

cat > /opt/allsafe/app.py <<'PY'
import json
from http.server import BaseHTTPRequestHandler, HTTPServer
class H(BaseHTTPRequestHandler):
    def do_GET(self):
        b=json.dumps({"status":"ok"}).encode()
        self.send_response(200); self.send_header("Content-Length",str(len(b))); self.end_headers(); self.wfile.write(b)
    def log_message(self,*a): pass
HTTPServer(("127.0.0.1",8080),H).serve_forever()
PY

# Servicio que corre como ROOT (hueco de seguridad).
cat > /etc/systemd/system/allsafe-api.service <<'U'
[Unit]
Description=allsafe-api
After=network.target

[Service]
ExecStart=/usr/bin/python3 /opt/allsafe/app.py
Restart=always

[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload
systemctl enable --now allsafe-api.service >/dev/null 2>&1 || true

# Secreto legible por todos (hueco).
install -d -m 0755 /etc/allsafe
echo 'SECRET_KEY=s3cr3t-prod' > /etc/allsafe/secret.env
chmod 644 /etc/allsafe/secret.env

install -d -m 0755 /var/backups/allsafe
chown -R analista:analista /opt/allsafe

cat > /home/analista/checklist.txt <<'TXT'
CHECKLIST DE GO-LIVE · allsafe-api
Marca cada punto [x] cuando esté hecho y DEMOSTRADO en el sistema.

[ ] 1. Seguridad: el servicio NO corre como root (User= en el unit).
[ ] 2. Secreto: /etc/allsafe/secret.env con permisos 600.
[ ] 3. Backups: /usr/local/bin/backup.sh + timer allsafe-backup habilitado,
       y al menos un backup en /var/backups/allsafe.
[ ] 4. Runbook: /opt/allsafe/RUNBOOK.md con secciones Despliegue, Rollback y Contacto.
[ ] 5. Rollback: /usr/local/bin/rollback.sh ejecutable.

Aprobado por:
TXT
chown analista:analista /home/analista/checklist.txt

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Revisión antes de salir (go-live)

allsafe-api va a producción pero la revisión encontró huecos. Ciérralos TODOS y
deja constancia en ~/checklist.txt (marca [x] cada punto y pon "Aprobado por:").

1. Seguridad: haz que el servicio corra como 'appuser' (User=appuser), no root.
2. Secreto: /etc/allsafe/secret.env a permisos 600.
3. Backups: crea /usr/local/bin/backup.sh (copia db/estado a /var/backups/allsafe),
   un timer systemd 'allsafe-backup' habilitado, y ejecuta un backup de prueba.
4. Runbook: /opt/allsafe/RUNBOOK.md con secciones '## Despliegue', '## Rollback'
   y '## Contacto'.
5. Rollback: /usr/local/bin/rollback.sh ejecutable (vuelve a la versión anterior).

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 158 plantado."
