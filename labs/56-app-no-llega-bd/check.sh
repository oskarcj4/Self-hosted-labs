#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 56. Prueba la conexión real desde app-01 y lee el estado
# de db-01 con su agente de inventario (sólo lectura, puerto 9100).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
DB_IP=10.76.56.20

echo "== Lab 56 · La app no llega a la BD — comprobación =="

ip=$(getent hosts db.interno | awk '{print $1; exit}')
if [ "$ip" = "$DB_IP" ]; then ok "db.interno resuelve a la IP actual de db-01 ($DB_IP)."
else no "db.interno resuelve a '${ip:-nada}' (db-01 es $DB_IP)."; fi

if nc -z -w 3 "$DB_IP" 5432 2>/dev/null; then ok "app-01 abre conexión TCP con db-01:5432."
else no "No hay conexión TCP de app-01 a $DB_IP:5432."; fi

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 http://127.0.0.1:8080/health)
if [ "$code" = 200 ]; then ok "orders-app /health responde 200."
else no "orders-app /health responde ${code:-nada}: curl http://127.0.0.1:8080/health para ver el error."; fi

state=$(curl -s --max-time 4 "http://$DB_IP:9100/state")
if [ -z "$state" ]; then
  no "No se pudo leer el estado de db-01 (agente en :9100). ¿Lo has parado o bloqueado?"
else
  live=$(echo "$state" | sed -n '/^## iptables/,/^## rules.v4/p')
  saved=$(echo "$state" | sed -n '/^## rules.v4/,/^## listen/p')
  # Una regla ACCEPT es "abierta" si no es lo/establecidas/22/9100 y no lleva -s.
  open_rule(){ grep -E -- '-A INPUT.*-j ACCEPT' | grep -vE -- '-i lo|ctstate|--state|--dport (22|9100)( |$)' | grep -v -- ' -s '; }
  if echo "$live" | grep -q -- '-P INPUT DROP' && [ -z "$(echo "$live" | open_rule)" ]; then
    ok "El firewall de db-01 sigue en default-deny y sin reglas abiertas a todos."
  else
    no "El firewall de db-01 ya no es default-deny o tiene un ACCEPT sin origen (-s): ábrelo sólo a app-01."
  fi
  allow='-s 10\.76\.56\.(10/32|0/24)( |.*)--dport 5432|--dport 5432.*-s 10\.76\.56\.(10/32|0/24)'
  if echo "$live" | grep -qE -- "$allow"; then ok "Hay una regla que permite 5432 desde app-01."
  else no "No hay una regla en ejecución que permita 5432 desde 10.76.56.10 (o 10.76.56.0/24)."; fi
  if echo "$saved" | grep -qE -- "$allow" && ! echo "$saved" | grep -q '10\.76\.56\.99'; then
    ok "El cambio está guardado en /etc/iptables/rules.v4 (sobrevive a un reinicio)."
  else
    no "/etc/iptables/rules.v4 en db-01 no tiene la regla nueva (o aún permite la IP vieja .99)."
  fi
  if echo "$state" | sed -n '/^## listen/,$p' | grep -qE '127\.0\.0\.1:5432'; then
    no "minidb sigue escuchando en 127.0.0.1:5432."
  else
    ok "minidb escucha en una interfaz alcanzable desde la red."
  fi
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Conexión app -> BD restaurada capa a capa."; exit 0; } || exit 1
