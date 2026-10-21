#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 58. No espera a las 03:00: comprueba la programación y
# ejecuta el script con el entorno mínimo que le da cron, descarga el backup
# que sube y lo compara con los datos originales.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
SCRIPT=/usr/local/bin/backup-app.sh
CONF=/root/.config/rclone/rclone.conf
LOG=/var/log/backup-app.log
RC="rclone --config $CONF"

echo "== Lab 58 · Backup a Blob Storage — comprobación =="

if [ "$(systemctl is-active cron)" = active ] && [ "$(systemctl is-enabled cron 2>/dev/null)" = enabled ]; then
  ok "El servicio cron está en marcha y habilitado."
else
  no "cron no está activo y habilitado: sin cron no hay nada que se ejecute a las 03:00."
fi

line=$( { grep -hsE "^[^#]*backup-app\.sh" /etc/cron.d/* /etc/crontab | sed 's/^/D /'; \
          crontab -l -u root 2>/dev/null | grep -E "^[^#]*backup-app\.sh" | sed 's/^/U /'; } | head -1)
case "$line" in
  "D 0 3 * * * root "*|"U 0 3 * * * "*) ok "Programado a las 03:00 todos los días, como root." ;;
  "") no "No hay ninguna entrada de cron que lance backup-app.sh." ;;
  "D "*) no "La entrada de /etc/cron.d no es '0 3 * * * root ...' (en cron.d hace falta el usuario): ${line#D }" ;;
  *) no "La entrada del crontab de root no es '0 3 * * * ...': ${line#U }" ;;
esac

if [ -f "$CONF" ] && grep -q '^\[blob\]' "$CONF" && [ "$(stat -c %a "$CONF")" = 600 ]; then
  ok "Remote 'blob' configurado en $CONF y protegido (600)."
else
  no "Falta el remote [blob] en $CONF, o el fichero (tiene la clave) no es 600."
fi

if [ ! -x "$SCRIPT" ]; then
  no "$SCRIPT no existe o no es ejecutable."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

# 1) Con el cerrojo cogido, el script no debe subir nada.
before=$($RC lsf blob:backups 2>/dev/null | sort)
flock /run/lock/backup-app.lock sleep 8 &
sleep 0.5
timeout 6 env -i HOME=/root LOGNAME=root SHELL=/bin/sh PATH=/usr/bin:/bin "$SCRIPT" >/dev/null 2>&1
rc_locked=$?
wait
after=$($RC lsf blob:backups 2>/dev/null | sort)
if [ "$rc_locked" -ne 124 ] && [ "$before" = "$after" ]; then
  ok "Con otra ejecución en marcha (cerrojo cogido), el script sale sin hacer nada."
else
  no "Con /run/lock/backup-app.lock cogido, el script esperó o subió otro backup (usa flock -n)."
fi

# 2) Ejecución normal con el entorno de cron.
start=$(date +%s)
env -i HOME=/root LOGNAME=root SHELL=/bin/sh PATH=/usr/bin:/bin "$SCRIPT" >/dev/null 2>&1
rc=$?
if [ "$rc" -eq 0 ]; then ok "El script termina bien con el entorno mínimo de cron (exit 0)."
else no "El script falla con el entorno de cron (exit $rc). Pruébalo con: sudo env -i PATH=/usr/bin:/bin $SCRIPT"; fi

list=$($RC lsf blob:backups 2>/dev/null)
new=$(echo "$list" | grep -E "^app-$(date +%Y%m%d)-[0-9]{4}\.tar\.gz$" | sort | tail -1)
if [ -n "$new" ]; then
  ok "Backup de hoy subido con el nombre correcto ($new)."
  T=$(mktemp -d)
  if $RC copyto "blob:backups/$new" "$T/b.tar.gz" 2>/dev/null && tar xzf "$T/b.tar.gz" -C "$T" 2>/dev/null; then
    f=$(find "$T" -name clients.csv | head -1)
    if [ -n "$f" ] && cmp -s "$f" /srv/app/data/clients.csv \
       && [ "$(find "$T" -name 'factura-*.txt' | wc -l)" -eq 20 ]; then
      ok "El backup se restaura y su contenido coincide con /srv/app/data."
    else
      no "El backup se descarga, pero no contiene /srv/app/data completo."
    fi
  else
    no "El backup $new no se puede descargar o no es un .tar.gz válido."
  fi
  rm -rf "$T"
else
  no "No aparece en blob:backups un fichero app-$(date +%Y%m%d)-HHMM.tar.gz nuevo."
fi

old=$(echo "$list" | grep -cE "^app-($(date -d '15 days ago' +%Y%m%d)|$(date -d '11 days ago' +%Y%m%d))-0300")
keep=$(echo "$list" | grep -cE "^app-($(date -d '4 days ago' +%Y%m%d)|$(date -d '1 day ago' +%Y%m%d))-0300")
if [ "$old" -eq 0 ] && [ "$keep" -eq 2 ]; then
  ok "Retención de 7 días: se borraron los backups viejos y se conservan los recientes."
else
  no "Retención incorrecta: quedan $old backups de más de 7 días y $keep/2 de los recientes."
fi

if [ -f "$LOG" ] && [ "$(stat -c %Y "$LOG")" -ge $((start - 1)) ]; then
  ok "La ejecución quedó registrada en $LOG."
else
  no "No hay registro reciente en $LOG."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Backup nocturno verificado de punta a punta (incluida la restauración)."; exit 0; } || exit 1
