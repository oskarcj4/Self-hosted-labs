#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 55. Mide el espacio y los inodos reales (df), no lo que se
# borró.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"

echo "== Lab 55 · Disco lleno — comprobación =="

use=$(df --output=pcent /var/log/app 2>/dev/null | tail -1 | tr -dc '0-9')
if [ -n "$use" ] && [ "$use" -lt 50 ]; then
  ok "/var/log/app tiene espacio libre (uso ${use}%)."
else
  no "/var/log/app sigue casi lleno (uso ${use:-?}%). Objetivo: menos del 50 %."
fi

if $SUDO lsof -nP +L1 2>/dev/null | grep -q '/var/log/app'; then
  no "Hay ficheros borrados que algún proceso sigue teniendo abiertos en /var/log/app (lsof +L1)."
else
  ok "No quedan ficheros borrados ocupando espacio en /var/log/app."
fi

iuse=$(df --output=ipcent /srv/sessions 2>/dev/null | tail -1 | tr -dc '0-9')
if [ -n "$iuse" ] && [ "$iuse" -lt 50 ]; then
  ok "/srv/sessions tiene inodos libres (uso ${iuse}%)."
else
  no "/srv/sessions sigue sin inodos libres (IUse ${iuse:-?}%). Objetivo: menos del 50 %."
fi
live=$(ls /srv/sessions/ 2>/dev/null | grep -c '^sess-live-')
if [ "$live" -eq 15 ]; then
  ok "Las 15 sesiones activas siguen intactas."
else
  no "Faltan sesiones activas (quedan $live de 15): borra sólo las antiguas."
fi

for s in orders trace-collector; do
  if [ "$(systemctl is-active "$s")" = active ]; then ok "$s está en marcha."
  else no "$s no está activo (liberar espacio no es apagar servicios)."; fi
done

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:8080/health)
if [ "$code" = 200 ]; then ok "orders /health responde 200."
else no "orders /health responde ${code:-nada} (debe ser 200)."; fi

conf=$(grep -lsE '^[^#]*/var/log/app' /etc/logrotate.d/* 2>/dev/null | head -1)
if [ -z "$conf" ]; then
  no "No hay ninguna configuración de logrotate para /var/log/app en /etc/logrotate.d/."
else
  body=$(grep -v '^[[:space:]]*#' "$conf")
  miss=""
  echo "$body" | grep -qE '^[[:space:]]*rotate[[:space:]]+[0-9]+' || miss="$miss rotate"
  echo "$body" | grep -qE '^[[:space:]]*compress' || miss="$miss compress"
  echo "$body" | grep -qE '^[[:space:]]*(copytruncate|postrotate)' || miss="$miss copytruncate/postrotate"
  if [ -n "$miss" ]; then
    no "$conf no tiene:$miss."
  elif $SUDO logrotate -d "$conf" >/dev/null 2>&1; then
    ok "logrotate rota /var/log/app ($conf) y la config es válida."
  else
    no "logrotate -d $conf da error: revísalo."
  fi
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Discos recuperados y rotación en marcha."; exit 0; } || exit 1
