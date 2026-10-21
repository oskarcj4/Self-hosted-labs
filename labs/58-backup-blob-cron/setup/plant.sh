#!/usr/bin/env bash
# Lab 58: los datos de la app no tienen backup. Hay que programar uno nocturno
# (03:00) a un Blob Storage (Azurite) con retención de 7 días.
set -e
# --- Datos de la app
mkdir -p /srv/app/data/uploads /srv/app/data/config
python3 - <<'PY'
import random
random.seed(58)
with open("/srv/app/data/clients.csv", "w") as f:
    f.write("id,nombre,email,saldo\n")
    for i in range(1, 801):
        f.write(f"{i},Cliente {i},cliente{i}@ejemplo.com,{random.randint(0, 99999)/100:.2f}\n")
for i in range(1, 21):
    with open(f"/srv/app/data/uploads/factura-{i:04d}.txt", "w") as f:
        f.write(f"Factura {i}\n" + "línea de detalle\n" * random.randint(5, 50))
PY
printf 'APP_ENV=production\nFEATURE_X=on\n' > /srv/app/data/config/app.env

# --- Backups antiguos ya presentes en el contenedor 'backups' (hechos a mano
# en su día). La fecha que rclone usa para --min-age es la de modificación.
RC=/tmp/rclone-seed.conf
cat > $RC <<'EOF'
[seed]
type = azureblob
account = devstoreaccount1
key = Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==
endpoint = http://blob-01:10000/devstoreaccount1
EOF
for _ in $(seq 1 60); do rclone --config $RC mkdir seed:backups 2>/dev/null && break; sleep 1; done
mkdir -p /tmp/seed
for d in 15 11 4 1; do
  n="app-$(date -d "$d days ago" +%Y%m%d)-0300.tar.gz"
  tar czf "/tmp/seed/$n" -C /srv/app data
  touch -d "$d days ago" "/tmp/seed/$n"
done
rclone --config $RC copy /tmp/seed seed:backups
rm -rf /tmp/seed $RC

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/TAREA-202.txt <<'EOF'
TAREA-202 · Backup nocturno de files-01

Auditoría: /srv/app/data NO tiene backup automático. Hace meses alguien
subía copias a mano al Blob Storage y dejó de hacerlo.

Storage (emulador Azure Blob, red interna):
  endpoint   http://blob-01:10000/devstoreaccount1
  cuenta     devstoreaccount1
  clave      Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==
  contenedor backups

Requisitos de la política de backup:
  - Todos los días a las 03:00, como root.
  - Nombre: app-AAAAMMDD-HHMM.tar.gz
  - Retención: 7 días en el storage.
  - Log en /var/log/backup-app.log
  - Si una ejecución sigue en marcha, la siguiente NO arranca
    (cerrojo: /run/lock/backup-app.lock).
EOF
chown -R analista:analista /home/analista/ticket
echo "Lab 58 plantado."
