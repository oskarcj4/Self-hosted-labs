#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 67. Prueba conexiones reales desde app-04 y lee la config
# efectiva de pg-01 con su agente de estado (sólo lectura).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
pg(){ PGCONNECT_TIMEOUT=5 psql -XAt "host=pg-01 port=5432 $1" -c "${2:-SELECT 1}" 2>&1; }

echo "== Lab 67 · PostgreSQL rechaza conexiones remotas — comprobación =="

ST=$(curl -fs --max-time 5 http://pg-01:9100/state)
if [ -z "$ST" ] || ! echo "$ST" | grep -q '^listen|'; then
  no "pg-01 no responde (¿PostgreSQL parado? sudo systemctl status postgresql en pg-01)."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

listen=$(echo "$ST" | sed -n 's/^listen|//p')
if echo "$listen" | grep -q '\*\|0\.0\.0\.0'; then
  no "listen_addresses = '$listen': escucha en todas partes. El ticket pide localhost + la IP interna."
elif echo "$listen" | grep -q '10\.76\.67\.20'; then
  ok "PostgreSQL escucha en '$listen'."
else
  no "listen_addresses efectivo = '$listen' (no incluye 10.76.67.20). ¿Reiniciaste? ¿Hay otro fichero que lo pisa?"
fi

if timeout 3 bash -c '</dev/tcp/10.76.67.20/5432' 2>/dev/null; then
  ok "El puerto 5432 de pg-01 es alcanzable desde app-04."
else
  no "No se puede abrir una conexión TCP a 10.76.67.20:5432."
fi

out=$(pg "dbname=ventas user=informes password=Informes-2026" "SELECT count(*) FROM pedidos")
if [ "$out" != 1200 ]; then
  no "informes@ventas no conecta: $(echo "$out" | tail -1)"
  # Lo que NO debe funcionar sólo se puede comprobar cuando lo que sí debe, funciona.
  no "Pruebas negativas (contraseña mala, otra BD, superusuario): pendientes hasta que informes conecte."
else
ok "informes@ventas conecta desde app-04 (1200 pedidos)."

out=$(pg "dbname=ventas user=informes password=mala-clave")
echo "$out" | grep -q 'password authentication failed' \
  && ok "Con una contraseña incorrecta se rechaza (no hay 'trust')." \
  || no "Con una contraseña incorrecta no da 'password authentication failed': $(echo "$out" | tail -1)"

out=$(pg "dbname=postgres user=informes password=Informes-2026")
echo "$out" | grep -qE 'rejects connection|no pg_hba.conf entry' \
  && ok "informes no puede entrar a otras bases de datos por red." \
  || no "informes puede conectar a la BD 'postgres' por red: la excepción debe ser sólo para 'ventas'."
out=$(pg "dbname=ventas user=postgres password=x")
echo "$out" | grep -qE 'rejects connection|no pg_hba.conf entry' \
  && ok "El superusuario postgres no puede entrar por red." \
  || no "postgres llega a pedir contraseña por red: la excepción debe ser sólo para 'informes'."
fi

rules=$(echo "$ST" | grep '^rule|' | awk -F'|' '$3 ~ /^host/')
bad=$(echo "$rules" | awk -F'|' '$8 ~ /^(trust|md5|password)$/ {print "línea " $2 " (" $8 ")"}')
[ -z "$bad" ] && ok "Ninguna regla de red usa trust, md5 ni password." \
  || no "pg_hba.conf tiene reglas de red débiles: $bad"
mine=$(echo "$rules" | awk -F'|' '$4=="ventas" && $5=="informes" && $8=="scram-sha-256"')
echo "$mine" | grep -qE '\|10\.76\.67\.10\|255\.255\.255\.255\|' \
  && ok "Regla específica: host ventas informes 10.76.67.10/32 scram-sha-256." \
  || no "No hay una regla 'host ventas informes 10.76.67.10/32 scram-sha-256' (ni más ni menos)."
echo "$rules" | awk -F'|' '$4=="all" && $5=="all" && $6=="0.0.0.0" && $8=="reject"' | grep -q . \
  && ok "La regla 'reject' para el resto de la red sigue en su sitio." \
  || no "Quitaste la regla 'host all all 0.0.0.0/0 reject' del hardening."

out=$(bash -c '/usr/local/bin/informe-diario.sh' 2>&1)
echo "$out" | grep -q '^pedidos: 1200' && ok "informe-diario.sh: $out" \
  || no "informe-diario.sh falla: $(echo "$out" | tail -1)"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Excepción de red mínima y verificada."; exit 0; } || exit 1
