#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 73 (game day).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
PM=/home/analista/postmortem.md

echo "== Lab 73 · Game day — comprobación =="

use=$(df -P /srv/app/uploads | awk 'NR==2 {print $5+0}')
[ "$use" -lt 50 ] && ok "El volumen de subidas tiene espacio (${use}%)." \
  || no "/srv/app/uploads está al ${use}%."
n=$(ls /srv/app/uploads/pedido-20261019-*.pdf 2>/dev/null | wc -l)
[ "$n" -eq 10 ] && ok "Las 10 subidas de clientes siguen ahí." || no "Faltan subidas de clientes: hay $n de 10."

if systemctl is-active --quiet postgresql@15-main; then
  ok "PostgreSQL (postgresql@15-main) está en marcha."
else
  no "postgresql@15-main no está en marcha (ojo: 'postgresql.service' es sólo un envoltorio)."
fi
sb=$($SUDO runuser -u postgres -- psql -XAtc 'SHOW shared_buffers' 2>/dev/null)
[ "$sb" = 256MB ] && ok "shared_buffers = 256MB (el cambio CHG-7301 se mantiene, corregido)." \
  || no "shared_buffers = '${sb:-?}': el CHG-7301 pedía 256MB. Corrige la errata, no borres el cambio."

ip=$(getent hosts db.interno | awk '{print $1; exit}')
[ "$ip" = 127.0.0.1 ] && ok "db.interno resuelve a 127.0.0.1." || no "db.interno resuelve a '${ip:-nada}'."

h=$(curl -s --max-time 10 http://127.0.0.1:8080/health)
echo "$h" | grep -q '^tienda ok (240 productos)' && ok "/health: $h" || no "/health responde: ${h:-nada}"

if [ ! -s "$PM" ]; then
  no "Falta el postmortem en $PM."
else
  miss=""
  for s in "Resumen" "Cronolog" "Impacto" "Causa" "Acciones"; do
    body=$(awk -v s="$s" '/^## /{f = (index($0, s) > 0); next} f' "$PM" | grep -c '[[:alnum:]]')
    [ "$body" -ge 1 ] || miss="$miss $s"
  done
  [ -z "$miss" ] && ok "El postmortem tiene las 5 secciones con contenido." \
    || no "Al postmortem le faltan secciones (## ...) o están vacías:$miss"
  causes=0
  grep -qiE 'core|disco|espacio|lleno|uploads' "$PM" && causes=$((causes+1))
  grep -qiE 'shared_buffers|50-tuning|CHG-7301|postgres' "$PM" && causes=$((causes+1))
  grep -qiE 'db\.interno|/etc/hosts|hosts' "$PM" && causes=$((causes+1))
  [ $causes -eq 3 ] && ok "El postmortem cubre las tres causas." \
    || no "El postmortem sólo menciona $causes de las 3 causas (disco, PostgreSQL, db.interno)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Game day superado: servicio restaurado y postmortem escrito."; exit 0; } || exit 1
