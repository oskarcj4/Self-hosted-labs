#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 48 (Día 25).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/analytics
cid(){ docker ps -q --filter label=com.docker.compose.project=analytics --filter "label=com.docker.compose.service=$1" | head -1; }
has_secret(){ docker exec "$1" sh -c 'ls /run/secrets/ 2>/dev/null' | grep -q .; }

echo "== Lab 48 · Día 25 — comprobación =="

for s in upstream web worker reporter; do
  [ -n "$(cid $s)" ] || no "El servicio $s no está corriendo."
done

leak=""
for s in web worker upstream; do
  c=$(cid $s); [ -n "$c" ] || continue
  has_secret "$c" && leak="$leak $s"
done
if [ -z "$leak" ]; then ok "web, worker y upstream ya no reciben el secreto."
else no "Siguen recibiendo secretos en /run/secrets:$leak"; fi

r=$(cid reporter)
if [ -n "$r" ] && docker exec "$r" test -s /run/secrets/api_token; then
  ok "reporter sigue recibiendo /run/secrets/api_token."
else
  no "reporter ya no tiene /run/secrets/api_token (es el único que lo necesita)."
fi

st=""
for _ in $(seq 1 8); do
  st=$(docker exec "$r" cat /tmp/status 2>/dev/null)
  now=$(date +%s); ts=${st%% *}
  echo "$st" | grep -q " ok upstream ok" && [ $((now - ${ts:-0})) -lt 15 ] && break
  sleep 1
done
if echo "$st" | grep -q " ok upstream ok"; then ok "reporter sigue autenticándose contra upstream."
else no "reporter no consigue autenticarse: ${st:-sin estado}"; fi

if curl -s --max-time 3 http://127.0.0.1:8080/ | grep -q "panel interno ok"; then ok "El panel web sigue respondiendo."
else no "El panel web no responde en :8080."; fi

if (cd "$P" && docker compose config --format json 2>/dev/null) | python3 -c '
import json,sys
sv=json.load(sys.stdin)["services"]
bad=[n for n,s in sv.items() if n!="reporter" and s.get("secrets")]
sys.exit(1 if bad or not sv["reporter"].get("secrets") else 0)'; then
  ok "En compose.yaml el secreto sólo está asignado a reporter."
else
  no "compose.yaml asigna el secreto a servicios que no lo usan (revisa también los anclajes YAML)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Secreto sólo donde se usa. ¡Día 25 resuelto!"; exit 0; } || exit 1
