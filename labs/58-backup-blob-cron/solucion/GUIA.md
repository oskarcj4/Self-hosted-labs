# Resolución guiada · Backup nocturno a Blob Storage

:::piensa Tres trampas clásicas
1. **cron no es tu terminal.** Arranca con un entorno mínimo
   (`PATH=/usr/bin:/bin`), y `rclone` vive en `/usr/local/bin`. Lo que te
   funciona a ti falla a las 3 de la mañana.
2. **Un script que no para al fallar miente.** Sin las opciones adecuadas,
   bash sigue ejecutando después de un error y termina diciendo "OK".
3. **Un backup que no has restaurado no es un backup.**
:::

**El plan:** (1) configurar rclone, (2) escribir el script pensando en cron,
(3) programarlo, (4) probarlo como lo haría cron y (5) ensayar la
restauración.

## Paso 1 · Remote de rclone, con la clave protegida

**Objetivo:** que root pueda hablar con el storage usando el nombre `blob`.

**Pregúntate:** el fichero de configuración lleva la clave de la cuenta. ¿Quién
debería poder leerlo?

:::pista Cómo hacerlo
**rclone** es una herramienta para copiar ficheros a casi cualquier
almacenamiento en la nube. Cada destino configurado es un **remote** con
nombre; después lo usas como `blob:contenedor/fichero`.
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
sudo rclone lsl blob:backups
```
- `[blob]` es el nombre del remote; `type = azureblob` dice qué tipo de
  almacenamiento es. El resto son los datos de `~/ticket/TAREA-202.txt`.
- `chmod 600`: sólo root lee y escribe. Lleva la clave.
- `rclone lsl` lista los ficheros con tamaño y fecha.

**Qué deberías ver:** cuatro `app-…-0300.tar.gz` antiguos, hechos a mano.
:::

## Paso 2 · El script, escrito para cron

**Objetivo:** un script que haga el backup y que, si algo falla, falle de
verdad.

**Pregúntate:** ¿qué necesita para funcionar desde cron? ¿Y para no apilarse si
el de ayer sigue en marcha?

:::pista Cómo hacerlo
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

| Línea | Qué hace y por qué |
|---|---|
| `set -euo pipefail` | `-e`: si un comando falla, el script para. `-u`: usar una variable que no existe es un error. `-o pipefail`: en una tubería `a \| b`, si falla `a` cuenta como fallo (por defecto sólo cuenta `b`). Juntas evitan el "OK" falso. |
| `export PATH=…` | El `PATH` mínimo de cron no incluye `/usr/local/bin`, donde está `rclone`. Sin esta línea: `rclone: command not found` a las 3 AM. |
| `exec 9>/run/lock/backup-app.lock` | Abre el fichero del cerrojo y lo deja abierto como **descriptor 9** durante todo el script (`exec` sin comando redirige la propia shell). |
| `flock -n 9 \|\| { …; exit 1; }` | Intenta cerrar el cerrojo sobre ese descriptor. `-n` (*non-block*): si otro proceso ya lo tiene, no espera, falla al momento, y salimos. El cerrojo se libera solo cuando el script termina y se cierra el descriptor. |
| `mktemp -d` | Crea una carpeta temporal con nombre único (`/tmp/tmp.XXXX`). |
| `trap '…' EXIT` | Ejecuta ese comando al salir del script, pase lo que pase (bien, mal o por un error con `-e`). Aquí, borrar la carpeta temporal. |
| `tar czf … -C /srv/app data` | Crea (`c`) un `.tar.gz` (`z`) en el fichero (`f`). `-C /srv/app` entra en esa carpeta antes de empaquetar, así dentro del archivo la ruta es `data/…` y no `srv/app/data/…`. |
| `tar tzf … >/dev/null` | Lista (`t`) el archivo recién creado: si está corrupto, falla y `-e` para el script. |
| `rclone copyto origen destino` | Sube un fichero con ese nombre exacto (`copy` copiaría carpetas). |
| `rclone check … --one-way --include` | Compara tu fichero local con el subido (tamaño y hash). `--one-way` sólo mira que lo local esté en el destino; `--include` limita la comparación a este backup. |
| `rclone delete --min-age 7d` | Borra del contenedor los ficheros modificados hace **más de** 7 días: la retención. |
:::

## Paso 3 · Prográmalo a las 03:00 como root

**Pregúntate:** ¿`/etc/cron.d/` o `crontab -e`? ¿Está cron funcionando?

:::pista Cómo hacerlo
```bash
echo '0 3 * * * root /usr/local/bin/backup-app.sh' | sudo tee /etc/cron.d/backup-app
sudo systemctl enable --now cron
```
Los cinco primeros campos de una línea de cron son: **minuto, hora, día del
mes, mes y día de la semana**. `0 3 * * *` = minuto 0, hora 3, cualquier día.
En `/etc/cron.d/` el sexto campo es el **usuario** (`root`); en el crontab de
un usuario (`crontab -e`) ese campo no existe.

`enable --now`: en este servidor cron estaba **desactivado**. Sin eso, la
línea está perfecta y nunca se ejecuta.
:::

## Paso 4 · Pruébalo como lo hará cron

**Objetivo:** demostrar que funciona con el entorno mínimo de cron, no con el
tuyo.

:::pista Cómo hacerlo
```bash
sudo env -i HOME=/root PATH=/usr/bin:/bin /usr/local/bin/backup-app.sh; echo "exit=$?"
sudo rclone lsl blob:backups
tail -3 /var/log/backup-app.log
```
`env -i` arranca el comando con el entorno **vacío**, salvo lo que le pasas:
es la forma de imitar a cron.

**Qué deberías ver:** `exit=0`; en el storage, el backup de hoy y los de hace
1 y 4 días, pero **no** los de hace 11 y 15; y una línea `OK app-…` en el log.

Prueba también el cerrojo: con otro proceso sujetándolo, el script debe salir
sin hacer nada.
```bash
sudo flock /run/lock/backup-app.lock sleep 10 &
sleep 1; sudo env -i PATH=/usr/bin:/bin /usr/local/bin/backup-app.sh; echo "exit=$?"
```
**Qué deberías ver:** `exit=1` al instante, y `otra ejecución; salgo` en el log.
:::

## Paso 5 · Ensaya la restauración (el paso que todos saltan)

:::pista Cómo hacerlo
```bash
ULTIMO=$(sudo rclone lsf blob:backups | sort | tail -1); echo "$ULTIMO"
sudo rclone copyto "blob:backups/$ULTIMO" /tmp/r.tar.gz
sudo rm -rf /tmp/r && mkdir /tmp/r && sudo tar xzf /tmp/r.tar.gz -C /tmp/r
sudo diff -r /tmp/r/data /srv/app/data && echo "restauración OK"
bash /opt/lab/check.sh
```
- `rclone lsf` lista sólo nombres; como llevan la fecha en formato
  `AAAAMMDD-HHMM`, ordenarlos alfabéticamente es ordenarlos por fecha, y
  `tail -1` da el más reciente.
- `diff -r` compara dos carpetas recursivamente; si no imprime nada, son
  idénticas.
:::

## Cómo actuar en una situación así

- **Un backup no existe hasta que se restaura.** Ensaya la restauración
  periódicamente.
- Scripts de cron **para el entorno de cron**: `PATH` explícito, rutas
  absolutas, `set -euo pipefail`.
- Avisa también si **falta** el backup de hoy (*dead man's switch*), no sólo si
  falla: un cron apagado no falla, simplemente no hace nada.
- En Azure real, mejor un token SAS limitado al contenedor o una identidad
  gestionada que la clave de la cuenta.

## Si te atascas

- **Funciona en tu terminal y falla con `env -i`:** el `PATH` (rclone está en
  `/usr/local/bin`).
- **El check dice que con el cerrojo cogido el script esperó:** falta `-n` en
  `flock`.
- **No se borran los antiguos:** revisa `--min-age 7d` y que el `delete` vaya
  contra `blob:backups`.
- **"No pasa nada a las 3":** ¿`systemctl enable --now cron`? ¿Pusiste el
  usuario en la línea de `/etc/cron.d/`?
