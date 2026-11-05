#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 149.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
WEB=/var/www/html/index.html
CONF=/etc/aide/aide-www.conf

echo "== Lab 149 · Defacement de fsociety — comprobación =="

# 1) Restauración
if $SUDO grep -qi 'fsociety' "$WEB" 2>/dev/null; then
  no "La portada sigue pintada (todavía contiene 'fsociety')."
else
  ok "La portada ya no muestra el defacement."
fi
if $SUDO cmp -s "$WEB" /opt/backups/index.html.orig; then
  ok "index.html restaurado byte a byte desde el respaldo bueno."
else
  no "index.html no coincide con /opt/backups/index.html.orig."
fi

# 2) Línea base de AIDE
if [ -s /var/lib/aide/aide.db ]; then
  ok "Existe la base de datos de AIDE (/var/lib/aide/aide.db)."
  if $SUDO aide --check -c "$CONF" >/tmp/aide-check.out 2>&1; then
    ok "aide --check sale limpio sobre el estado restaurado."
  else
    # AIDE devuelve !=0 si detecta cambios: mostrar pista
    no "aide --check detecta diferencias (¿iniciaste la base DESPUÉS de restaurar?)."
  fi
else
  no "Falta la línea base de AIDE: inicia con 'aide --init -c $CONF' y copia .new a aide.db."
fi

# 3) Vigilancia activa (inotify o cron con aide)
ACTIVE=0
$SUDO systemctl is-active fim-www.service >/dev/null 2>&1 && ACTIVE=1
if [ "$ACTIVE" = 0 ] && $SUDO grep -rqs 'aide' /etc/cron.d /etc/cron.daily 2>/dev/null; then ACTIVE=1; fi
[ "$ACTIVE" = 1 ] && ok "Vigilancia de integridad activa (inotify o aide programado)." \
  || no "Monta vigilancia: servicio fim-www (inotifywait) activo o un cron con 'aide --check'."

# 4) Hallazgos
grep -qE '^pagina_afectada=/var/www/html/index\.html\s*$' $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: página afectada documentada." || no "hallazgos.txt: falta pagina_afectada=/var/www/html/index.html."
grep -qiE '^firma_defacement=fsociety\s*$' $H/hallazgos.txt 2>/dev/null \
  && ok "hallazgos: firma del defacement documentada." || no "hallazgos.txt: falta firma_defacement=fsociety."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Portada restaurada y webroot bajo vigilancia."; exit 0; } || exit 1
