#!/usr/bin/env bash
# Solución automática (corre como analista; sudo donde haga falta).
set -e

# 1) Servicio no root
sudo mkdir -p /etc/systemd/system/allsafe-api.service.d
sudo tee /etc/systemd/system/allsafe-api.service.d/user.conf >/dev/null <<'C'
[Service]
User=appuser
C
sudo systemctl daemon-reload
sudo systemctl restart allsafe-api

# 2) Secreto 600
sudo chmod 600 /etc/allsafe/secret.env

# 3) Backups: script + timer + backup de prueba
sudo tee /usr/local/bin/backup.sh >/dev/null <<'S'
#!/usr/bin/env bash
set -e
dst=/var/backups/allsafe/allsafe-$(date +%Y%m%d-%H%M%S).tar.gz
tar czf "$dst" -C /opt allsafe 2>/dev/null
echo "backup: $dst"
S
sudo chmod +x /usr/local/bin/backup.sh
sudo tee /etc/systemd/system/allsafe-backup.service >/dev/null <<'S'
[Unit]
Description=Backup de allsafe
[Service]
Type=oneshot
ExecStart=/usr/local/bin/backup.sh
S
sudo tee /etc/systemd/system/allsafe-backup.timer >/dev/null <<'T'
[Unit]
Description=Backup diario de allsafe
[Timer]
OnCalendar=daily
Persistent=true
[Install]
WantedBy=timers.target
T
sudo systemctl daemon-reload
sudo systemctl enable allsafe-backup.timer
sudo /usr/local/bin/backup.sh   # backup de prueba

# 4) Runbook
sudo tee /opt/allsafe/RUNBOOK.md >/dev/null <<'R'
# Runbook · allsafe-api

## Despliegue
1. Construir y publicar la imagen (ver lab 152).
2. `systemctl restart allsafe-api` y verificar `/healthz`.

## Rollback
Ejecuta `/usr/local/bin/rollback.sh` para volver a la versión anterior.
Criterio: error 5xx > 2% durante 5 min, o readiness en rojo.

## Contacto
Guardia SRE: canal #allsafe-oncall. Escalado: jefatura de plataforma.
R

# 5) rollback.sh
sudo tee /usr/local/bin/rollback.sh >/dev/null <<'RB'
#!/usr/bin/env bash
set -e
echo "Volviendo a la versión anterior de allsafe-api..."
# (en real: cambiar el tag/digest desplegado y reiniciar)
systemctl restart allsafe-api
echo "rollback hecho."
RB
sudo chmod +x /usr/local/bin/rollback.sh

# 6) Firmar el checklist
sed -i 's/^\[ \]/[x]/' /home/analista/checklist.txt
sed -i 's/^Aprobado por:.*/Aprobado por: analista/' /home/analista/checklist.txt
echo "solve.sh completado."
