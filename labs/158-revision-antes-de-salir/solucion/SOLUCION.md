# Solución — Revisión antes de salir

## Los cinco huecos

1. **Servicio no root** — override del unit:
```bash
sudo systemctl edit allsafe-api     # [Service]\nUser=appuser
sudo systemctl daemon-reload && sudo systemctl restart allsafe-api
sudo systemctl show allsafe-api -p User   # appuser
```

2. **Secreto 600**:
```bash
sudo chmod 600 /etc/allsafe/secret.env
```

3. **Backups** — script + timer + prueba:
```bash
# /usr/local/bin/backup.sh : tar czf /var/backups/allsafe/allsafe-<fecha>.tar.gz -C /opt allsafe
sudo chmod +x /usr/local/bin/backup.sh
# allsafe-backup.service (oneshot) + allsafe-backup.timer (OnCalendar=daily)
sudo systemctl enable allsafe-backup.timer
sudo /usr/local/bin/backup.sh       # backup de prueba
```

4. **Runbook** `/opt/allsafe/RUNBOOK.md` con `## Despliegue`, `## Rollback`,
   `## Contacto`.

5. **Rollback** `/usr/local/bin/rollback.sh` ejecutable (vuelve a la versión
   anterior y reinicia).

Y firma: marca `[x]` los 5 puntos de `~/checklist.txt` y pon `Aprobado por:`.

## Por qué cada punto

- **No root / secreto 600**: reduce el daño si la app se ve comprometida.
- **Backups probados**: un backup que nunca restauraste no es un backup (ver
  labs 150 y 176).
- **Runbook**: el conocimiento no puede vivir solo en una cabeza; a las 3 AM
  manda el documento.
- **Rollback**: poder volver atrás en minutos convierte un incidente en un
  susto. Sin rollback, cada despliegue es una apuesta.

## Más allá del lab

- Automatiza el checklist como gate del pipeline: si falta un punto, no despliega.
- Añade: alertas conectadas, límites de recursos, plan de capacidad, DR probado.
