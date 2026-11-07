#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
U=http://127.0.0.1:8080

echo "== Lab 173 · Verde, pero fallando — comprobación =="

C=$(tr 'A-Z' 'a-z' < /home/analista/causas.txt 2>/dev/null)
if echo "$C" | grep -q 'pool' && echo "$C" | grep -qE 'cpu|cuota|quota|throttl|estrangul' && echo "$C" | grep -qE 'dns|resolv|nameserver'; then
  ok "~/causas.txt nombra las tres causas (pool, CPU, DNS)."
else
  no "~/causas.txt debe explicar las tres causas (una por línea)."
fi

T0=$(date +%s%N); getent hosts pagos.interno >/dev/null; T1=$(date +%s%N)
MS=$(( (T1 - T0) / 1000000 ))
if [ "$MS" -lt 500 ] && ! grep -qE '^\s*nameserver\s+127\.0\.0\.2' /etc/resolv.conf; then
  ok "DNS: pagos.interno resuelve en ${MS} ms (sin el nameserver muerto)."
else
  no "DNS: pagos.interno tarda ${MS} ms en resolver."
fi

Q=$(systemctl show tienda -p CPUQuotaPerSecUSec --value)
case "$Q" in
  infinity) QOK=1 ;;
  *ms) v=${Q%ms}; v=${v%.*}; [ "$v" -ge 500 ] && QOK=1 || QOK=0 ;;
  *s) v=${Q%s}; v=${v%.*}; [ "$v" -ge 1 ] && QOK=1 || QOK=0 ;;
  *) QOK=0 ;;
esac
if [ "$QOK" = 1 ]; then
  ok "CPU: la tienda ya no está estrangulada (CPUQuota=$Q por segundo)."
else
  no "CPU: tienda.service sigue con CPUQuota muy baja ($Q por segundo)."
fi

# Fuga del pool: 8 pagos rechazados seguidos y luego compras normales.
for _ in $(seq 1 8); do curl -s -o /dev/null --max-time 10 "$U/comprar?tarjeta=rechazada"; done
sleep 2
for _ in 1 2 3 4 5 6; do
  P=$(curl -s --max-time 5 "$U/pool"); echo "$P" | grep -qE 'en_uso=[01] ' && break; sleep 0.5
done
if echo "$P" | grep -qE 'en_uso=[01] '; then
  ok "Pool: tras 8 pagos rechazados no queda ninguna conexión sin devolver ($P)."
else
  no "Pool: tras 8 pagos rechazados quedan conexiones sin devolver ($P)."
fi

R=$(mktemp)
for i in $(seq 1 30); do
  curl -s -o /dev/null -w '%{http_code} %{time_total}\n' --max-time 10 "$U/comprar?tarjeta=buena" >> "$R" &
  [ $((i % 5)) -eq 0 ] && wait
done
wait
OKN=$(grep -c '^200 ' "$R")
P95=$(awk '{print $2}' "$R" | sort -n | awk '{a[NR]=$1} END{print a[int(NR*0.95)]}')
rm -f "$R"
if [ "$OKN" = 30 ] && awk -v p="$P95" 'BEGIN{exit !(p < 0.5)}'; then
  ok "Usuarios: 30/30 compras OK con 5 en paralelo, p95=${P95}s."
else
  no "Usuarios: $OKN/30 compras OK, p95=${P95}s (objetivo: 30/30 y p95 < 0.5 s)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Verde de verdad: lo que ve el usuario, no sólo /health."; exit 0; } || exit 1
