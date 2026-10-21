#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 61. Resuelve con getent (el mismo camino que usan las
# aplicaciones), no sólo con dig.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
API=10.76.61.30

echo "== Lab 61 · DNS roto — comprobación =="

first=$(awk '/^[[:space:]]*nameserver/ {print $2; exit}' /etc/resolv.conf)
[ "$first" = 10.76.61.53 ] && ok "El primer nameserver de /etc/resolv.conf es dns-01 (10.76.61.53)." \
  || no "El primer nameserver de /etc/resolv.conf es '${first:-ninguno}', no dns-01."
grep -qE '^[[:space:]]*(search|domain)[[:space:]].*\binterno\b' /etc/resolv.conf \
  && ok "resolv.conf busca los nombres cortos en la zona 'interno'." \
  || no "resolv.conf no tiene 'search interno': el nombre corto 'pagos' no se completa."
grep -qE '^hosts:.*\bdns\b' /etc/nsswitch.conf \
  && ok "nsswitch.conf consulta el DNS para 'hosts'." \
  || no "La línea 'hosts:' de /etc/nsswitch.conf no incluye 'dns'."

if grep -vE '^[[:space:]]*#' /etc/hosts | grep -qwE 'pagos(\.interno)?'; then
  no "Hay una entrada para 'pagos' en /etc/hosts: eso es un parche, no un arreglo (la IP cambia en cada despliegue)."
else
  ok "/etc/hosts no tiene entradas a mano para 'pagos'."
fi

for n in pagos.interno pagos; do
  ip=$(getent hosts "$n" | awk '{print $1; exit}')
  [ "$ip" = "$API" ] && ok "getent hosts $n -> $API" || no "getent hosts $n devuelve '${ip:-nada}' (debe ser $API)."
done

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 8 http://127.0.0.1:8080/health)
[ "$code" = 200 ] && ok "checkout /health responde 200 (llega a la API de pagos)." \
  || no "checkout /health responde ${code:-nada}: curl -s http://127.0.0.1:8080/health"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Resolución de nombres restaurada en todas sus capas."; exit 0; } || exit 1
