# Resolución guiada · Backup nocturno a Blob Storage

:::piensa Antes de tocar nada
Tres trampas clásicas de cron+backup: (1) cron arranca con un entorno mínimo
(`PATH=/usr/bin:/bin`) y `rclone` vive en `/usr/local/bin`; lo que te funciona
en la terminal falla a las 3 AM. (2) sin `set -euo pipefail` un paso roto dice
"OK". (3) un backup no está terminado hasta que lo **restauras**.
:::

## Paso 1 · Remote de rclone (con la clave protegida)

**Pregúntate:** ¿dónde va la config de root y con qué permisos? Lleva la clave
→ `600`.

:::pista Cómo hacerlo
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
sudo rclone lsl blob:backups      # ya hay copias viejas hechas a mano
```
En Azure real, mejor un token SAS acotado al contenedor o identidad gestionada,
no la clave de cuenta.
:::

## Paso 2 · El script, escrito para el entorno de cron

**Pregúntate:** ¿qué hace falta para que funcione **desde cron** y no mienta si
algo falla? `PATH` explícito, `set -euo pipefail`, cerrojo y verificación de la
subida.

:::pista `/usr/local/bin/backup-app.sh`
```bash
sudo tee /usr/local/bin/backup-app.sh >/dev/null <<'EOF'
#!/bin/bash
set -euo pipefail
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
LOG=/var/log/backup-app.log
exec 9>/run/lock/backup-app.lock
flock -n 9 || { echo "$(date '+%F %T') otra ejecución; salgo" >>"$LOG"; exit 1; }
NAME="app-$(date +%Y%m%d-%H%M).tar.gz"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
log(){ echo "$(date '+%F %T') $*" >>"$LOG"; }
log "inicio $NAME"
tar czf "$TMP/$NAME" -C /srv/app data
tar tzf "$TMP/$NAME" >/dev/null
rclone copyto "$TMP/$NAME" "blob:backups/$NAME"
rclone check "$TMP" blob:backups --one-way --include "$NAME"
rclone delete --min-age 7d blob:backups
log "OK $NAME ($(stat -c %s "$TMP/$NAME") bytes)"
EOF
sudo chmod 700 /usr/local/bin/backup-app.sh
```
Por qué cada pieza:
- `export PATH=...`: cron no tiene `/usr/local/bin`; sin esto, `rclone: command not found`.
- `set -euo pipefail`: un fallo corta y cron lo registra, en vez de "OK" falso.
- `flock -n 9`: si el backup de ayer sigue colgado, el de hoy no se apila.
- `rclone check`: confirma que el fichero llegó entero.
- `--min-age 7d`: retención; sin ella el storage (y la factura) crecen sin fin.
:::

## Paso 3 · Prográmalo a las 03:00 como root

**Pregúntate:** ¿`/etc/cron.d/` o `crontab -e`? En `/etc/cron.d/` cada línea
lleva el **usuario** (6.º campo). Y ojo: cron puede estar apagado.

:::pista Cómo hacerlo
```bash
echo '0 3 * * * root /usr/local/bin/backup-app.sh' | sudo tee /etc/cron.d/backup-app
sudo systemctl enable --now cron      # estaba desactivado
```
:::

## Paso 4 · Pruébalo como lo hará cron (no desde tu shell)

**Pregúntate:** ¿funciona con el entorno pelado de cron, no con el tuyo?

```bash
sudo env -i HOME=/root PATH=/usr/bin:/bin /usr/local/bin/backup-app.sh; echo "exit=$?"
sudo rclone lsl blob:backups     # el nuevo, y sin los de +7 días
tail /var/log/backup-app.log
```

## Paso 5 · Ensaya la restauración (el paso que todos saltan)

```bash
sudo rclone copyto blob:backups/app-AAAAMMDD-HHMM.tar.gz /tmp/r.tar.gz
mkdir /tmp/r && tar xzf /tmp/r.tar.gz -C /tmp/r
diff -r /tmp/r/data /srv/app/data && echo "restauración OK"
bash /opt/lab/check.sh
```

## Cómo actuar en una situación así

- **Un backup no existe hasta que se restaura.** Ensaya la restauración.
- **Scripts de cron para el entorno de cron**: `PATH` explícito, rutas
  absolutas, `set -euo pipefail`.
- **Cerrojo `flock -n`** contra solapes.
- **Retención** siempre, o el storage crece sin límite.
- **Alerta por ausencia** (dead man's switch): avisa si falta el backup de hoy,
  no sólo cuando falla.

## Si te atascas

- Funciona en tu shell y falla en cron → `PATH` (rclone en `/usr/local/bin`).
- "No pasa nada a las 3" → ¿`systemctl enable --now cron`? ¿usuario en la línea
  de `/etc/cron.d/`?
- Dice "OK" pero no subió → faltó `set -euo pipefail` o `rclone check`.
