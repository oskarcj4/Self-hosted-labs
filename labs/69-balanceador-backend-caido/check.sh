#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 69. Avería app2 y app3, mide 30 peticiones a través del
# balanceador, y luego los "arregla" y espera a que vuelvan a recibir tráfico.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
ctl(){ for a in 22 23; do curl -fs --max-time 3 "http://10.76.69.$a:8080/__lab/$1" >/dev/null; done; }
req(){ curl -s -o /tmp/.b69 -w '%{http_code} %{time_total}' --max-time 15 http://127.0.0.1/; }

echo "== Lab 69 · Balanceador con backends caídos — comprobación =="

$SUDO nginx -t >/dev/null 2>&1 && ok "Config de nginx válida." || no "nginx -t falla."
conf=$($SUDO nginx -T 2>/dev/null)
up=$(echo "$conf" | awk '/upstream tienda/{f=1} f; f&&/}/{exit}')
n=$(echo "$up" | grep -cE '^[[:space:]]*server[[:space:]]+10\.76\.69\.(21|22|23):8080')
if [ "$n" -eq 3 ] && ! echo "$up" | grep -qE '^[[:space:]]*server.*[[:space:]](down|backup)'; then
  ok "Los 3 backends siguen en el upstream, sin 'down' ni 'backup'."
else
  no "El upstream 'tienda' debe seguir con app1, app2 y app3 activos (sin 'down'/'backup')."
fi
echo "$conf" | grep -qE 'proxy_next_upstream[^;]*non_idempotent' \
  && no "proxy_next_upstream incluye non_idempotent: los POST se reintentarían (pedidos duplicados)." \
  || ok "Los POST no se reintentan en otro backend."

ctl break
echo "  (app2 devuelve 503 y app3 tarda 8 s; 30 peticiones a través de lb-01...)"
bad=0; slow=0; worst=0
for _ in $(seq 1 30); do
  read -r code t <<< "$(req)"
  [ "$code" = 200 ] || bad=$((bad + 1))
  awk -v t="$t" 'BEGIN{exit !(t >= 3)}' && slow=$((slow + 1))
  worst=$(awk -v a="$worst" -v b="$t" 'BEGIN{print (b > a) ? b : a}')
done
[ $bad -eq 0 ] && ok "30/30 peticiones con 200." || no "$bad de 30 peticiones no dieron 200."
[ $slow -eq 0 ] && ok "Ninguna tardó 3 s o más (la peor: ${worst}s)." \
  || no "$slow de 30 peticiones tardaron 3 s o más (la peor: ${worst}s)."

ctl heal
echo "  (app2 y app3 arreglados; esperando a que vuelvan a recibir tráfico, hasta 40 s...)"
seen=""; t0=$(date +%s)
while [ $(( $(date +%s) - t0 )) -lt 40 ]; do
  req >/dev/null; seen="$seen $(cut -d' ' -f1 /tmp/.b69)"
  echo "$seen" | grep -q app2 && echo "$seen" | grep -q app3 && break
  sleep 0.5
done
if echo "$seen" | grep -q app2 && echo "$seen" | grep -q app3; then
  ok "app2 y app3 volvieron a recibir tráfico solos en ~$(( $(date +%s) - t0 ))s."
else
  no "En 40 s app2/app3 no volvieron a recibir tráfico (¿fail_timeout demasiado largo?)."
fi
ctl break; rm -f /tmp/.b69

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 El balanceador aísla los backends enfermos y los recupera solo."; exit 0; } || exit 1
