#!/usr/bin/env bash
# Valida que la base se restauró del backup bueno Y que la app volvió a
# conectar con ella.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
Q(){ sudo -u postgres psql -tAqX -d tienda -c "$1" 2>/dev/null; }

echo "== Lab 108 · restaurar backup y reconectar la app =="

# 1) La base existe otra vez.
EX=$(sudo -u postgres psql -tAqX -c "SELECT 1 FROM pg_database WHERE datname='tienda'")
if [ "$EX" = "1" ]; then ok "la base 'tienda' existe de nuevo."
else no "no existe la base 'tienda' (restáurala desde el backup bueno)."; echo "Resultado: $pass ok, $((fail)) pend."; exit 1; fi

# 2) Datos del backup presentes (240 productos, 1200 pedidos).
P=$(Q "SELECT count(*) FROM productos")
PD=$(Q "SELECT count(*) FROM pedidos")
[ "$P" = "240" ] && ok "240 productos restaurados." || no "productos=$P (esperado 240): ¿restauraste el dump correcto y completo?"
[ "$PD" = "1200" ] && ok "1200 pedidos restaurados." || no "pedidos=$PD (esperado 1200)."

# 3) La app apunta a la base buena (no al failover inventado).
CONF=$(cat /etc/tienda/db.conf 2>/dev/null)
echo "$CONF" | grep -q 'dbname=tienda\b' && ! echo "$CONF" | grep -q 'tienda_dr' \
  && ok "db.conf apunta a dbname=tienda." \
  || no "db.conf sigue apuntando mal (¿tienda_dr / puerto 5433?)."

# 4) La app reconectó: /health 200 y ve los 240 productos.
H=$(curl -s http://127.0.0.1:8080/health)
HC=$(echo "$H" | jq -r '.status' 2>/dev/null)
HN=$(echo "$H" | jq -r '.productos' 2>/dev/null)
if [ "$HC" = "ok" ] && [ "$HN" = "240" ]; then
  ok "tienda-web responde ok y ve 240 productos (reconectada)."
else
  no "tienda-web aún no conecta ($H). Arregla db.conf y reinicia el servicio."
fi

echo "Resultado: $pass ok, $fail pend."
if [ "$fail" -eq 0 ]; then
  echo "🎉 Lab 108 resuelto. Base restaurada y app reconectada."
  touch /tmp/.tclab-solved; exit 0
fi
echo "Aún no. Revisa la GUIA: elegir el backup bueno, restaurar y reconectar la app."
exit 1
