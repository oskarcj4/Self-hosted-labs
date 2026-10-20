#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 42 (Día 19).
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/billing
IP=$(hostname -i 2>/dev/null | awk '{print $1}')

echo "== Lab 42 · Día 19 — comprobación =="

binds=""
for c in $(docker ps -q); do
  binds="$binds $(docker inspect -f '{{with index .NetworkSettings.Ports "5555/tcp"}}{{range .}}{{.HostIp}} {{end}}{{end}}' "$c")"
done
binds=$(echo $binds)
if [ -z "$binds" ]; then
  no "Ningún contenedor publica 5555: soporte necesita la consola desde este servidor (127.0.0.1:5555)."
elif echo "$binds" | tr ' ' '\n' | grep -vqxE '127\.0\.0\.1|::1'; then
  no "La consola se publica en interfaces externas (HostIp: $binds)."
else
  ok "La consola sólo se publica en loopback ($binds)."
fi

if curl -s --max-time 2 "http://$IP:5555/" >/dev/null 2>&1; then
  no "La consola responde desde la red ($IP:5555)."
else
  ok "Desde la red ($IP:5555) la consola ya no responde."
fi

if curl -s --max-time 3 "http://127.0.0.1:5555/" | grep -q "debug-console"; then
  ok "Soporte sigue llegando a la consola en 127.0.0.1:5555."
else
  no "La consola no responde en 127.0.0.1:5555."
fi

if curl -s --max-time 3 "http://$IP:8000/" | grep -q "billing-api ok"; then
  ok "La API sigue pública en :8000."
else
  no "La API ya no responde en $IP:8000."
fi

if (cd "$P" && docker compose config --format json 2>/dev/null) | python3 -c '
import json,sys
c=json.load(sys.stdin)
bad=[p for s in c["services"].values() for p in s.get("ports",[])
     if str(p.get("target"))=="5555" and p.get("host_ip","") not in ("127.0.0.1","::1")]
sys.exit(1 if bad else 0)'; then
  ok "compose.yaml publica la consola sólo en loopback."
else
  no "compose.yaml sigue publicando 5555 en todas las interfaces."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Consola de debug sólo en local. ¡Día 19 resuelto!"; exit 0; } || exit 1
