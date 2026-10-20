#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 41 (Día 18).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/shop
PROJ=shop
IP=$(hostname -i 2>/dev/null | awk '{print $1}')
cid(){ docker ps -q --filter "label=com.docker.compose.project=$PROJ" --filter "label=com.docker.compose.service=$1" | head -1; }

echo "== Lab 41 · Día 18 — comprobación =="

pub=""
for c in $(docker ps -q); do
  b=$(docker inspect -f '{{with index .NetworkSettings.Ports "9100/tcp"}}{{range .}}{{.HostIp}}:{{.HostPort}} {{end}}{{end}}' "$c")
  [ -n "$b" ] && pub="$pub $(docker inspect -f '{{.Name}}' "$c")=$b"
done
if [ -z "$pub" ]; then ok "Ningún contenedor publica el puerto de métricas 9100 en el host."
else no "El puerto de métricas sigue publicado:$pub"; fi

if curl -s --max-time 2 "http://$IP:9100/metrics" >/dev/null 2>&1 || curl -s --max-time 2 http://127.0.0.1:9100/metrics >/dev/null 2>&1; then
  no "Las métricas siguen respondiendo desde el host (:9100)."
else
  ok "Desde el host, :9100 ya no responde."
fi

if curl -s --max-time 3 "http://$IP:8080/" | grep -q "Tienda Norte"; then ok "La web sigue publicada en :8080."
else no "La web de la tienda ya no responde en $IP:8080."; fi

s=$(cid scraper)
if [ -n "$s" ] && docker exec "$s" wget -qO- -T 3 http://shop:9100/metrics 2>/dev/null | grep -q shop_orders_total; then
  ok "El scraper sigue leyendo las métricas por la red interna (shop:9100)."
else
  no "El scraper no puede leer http://shop:9100/metrics (¿sigue corriendo y en la misma red que shop?)."
fi

if (cd "$P" && docker compose config 2>/dev/null) | grep -qE 'published: "?9100'; then
  no "compose.yaml todavía publica 9100: el próximo 'docker compose up' lo volvería a exponer."
else
  ok "compose.yaml ya no publica 9100."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Métricas sólo en la red interna. ¡Día 18 resuelto!"; exit 0; } || exit 1
