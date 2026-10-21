# Solución — Backup nocturno a Blob Storage

## 1. Remote de rclone

Puedes usar el asistente (`sudo rclone config`) o escribir el fichero:

```bash
sudo mkdir -p /root/.config/rclone
sudo tee /root/.config/rclone/rclone.conf >/dev/null <<'EOF'
[blob]
type = azureblob
account = devstoreaccount1
key = Eby8vdM02xNOcqFlqUwJPLlmEtlCDXJ1OUzFT50uSRZ6IFsuFq2UVErCz4I6tq/K1SZFPTOtr/KBHBeksoGMGw==
endpoint = http://blob-01:10000/devstoreaccount1
EOF
sudo chmod 600 /root/.config/rclone/rclone.conf
sudo rclone lsl blob:backups          # ya hay 4 backups viejos hechos a mano
```

En Azure de verdad, `endpoint` sería `https://<cuenta>.blob.core.windows.net`.
Lo mejor es no usar la clave de la cuenta sino un token SAS acotado al
contenedor (`sas_url`), o una identidad gestionada.

## 2. El script

```bash
sudo tee /usr/local/bin/backup-app.sh >/dev/null <<'EOF'
#!/bin/bash
# Backup diario de /srv/app/data a blob:backups con retención de 7 días.
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG=/var/log/backup-app.log
exec 9>/run/lock/backup-app.lock
if ! flock -n 9; then
  echo "$(date '+%F %T') otra ejecución en marcha; salgo" >> "$LOG"
  exit 1
fi
NAME="app-$(date +%Y%m%d-%H%M).tar.gz"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
log(){ echo "$(date '+%F %T') $*" >> "$LOG"; }

log "inicio $NAME"
tar czf "$TMP/$NAME" -C /srv/app data
tar tzf "$TMP/$NAME" >/dev/null                    # el archivo se lee bien
rclone copyto "$TMP/$NAME" "blob:backups/$NAME"
rclone check "$TMP" blob:backups --one-way --include "$NAME"   # subida íntegra
rclone delete --min-age 7d blob:backups
log "OK $NAME ($(stat -c %s "$TMP/$NAME") bytes)"
EOF
sudo chmod 700 /usr/local/bin/backup-app.sh
```

Puntos clave:

- `set -euo pipefail`: si falla cualquier paso, el script termina con error
  (y cron lo registra) en vez de seguir y decir "OK".
- `export PATH=...`: cron usa `PATH=/usr/bin:/bin` y `rclone` está en
  `/usr/local/bin`. Sin esta línea, el script funciona en tu terminal y falla a
  las 3 AM.
- `flock -n`: si el backup de ayer sigue colgado, el de hoy no se apila encima.
- `rclone check` después de subir: comprueba que el fichero llegó entero.

## 3. Programarlo

```bash
echo '0 3 * * * root /usr/local/bin/backup-app.sh' | sudo tee /etc/cron.d/backup-app
sudo systemctl enable --now cron          # ¡estaba desactivado!
```

En `/etc/cron.d/` cada línea lleva el **usuario** (6.º campo). En `crontab -e`
no.

## 4. Probarlo como lo haría cron

```bash
sudo env -i HOME=/root PATH=/usr/bin:/bin /usr/local/bin/backup-app.sh; echo "exit=$?"
sudo rclone lsl blob:backups       # el nuevo, y sin los de más de 7 días
tail /var/log/backup-app.log
```

## 5. Ensaya la restauración

```bash
sudo rclone copyto blob:backups/app-AAAAMMDD-HHMM.tar.gz /tmp/r.tar.gz
mkdir /tmp/r && tar xzf /tmp/r.tar.gz -C /tmp/r
diff -r /tmp/r/data /srv/app/data && echo "restauración OK"
```

## Lecciones

- Un backup no está terminado hasta que lo has **restaurado**.
- Escribe los scripts de cron para el entorno de cron: `PATH` explícito, rutas
  absolutas y `set -euo pipefail`.
- Cerrojo (`flock -n`) para que no se solapen ejecuciones.
- La retención también es parte del backup: sin ella, el storage crece sin
  límite y la factura también.
- Para alertas, lo siguiente sería avisar si falta el backup de hoy (un
  healthcheck o un "dead man's switch"), no sólo cuando falla.
