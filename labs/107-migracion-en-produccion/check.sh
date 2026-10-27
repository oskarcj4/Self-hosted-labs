#!/usr/bin/env bash
# Valida que la migración quedó BIEN y es segura para producción:
#  - columna total_eur numeric, NOT NULL,
#  - backfill completo y correcto (= total/100),
#  - las filas NUEVAS se rellenan solas (trigger/sincronía) -> no se pierden
#    pedidos hechos durante la migración,
#  - la API sigue viva.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
Q(){ sudo -u postgres psql -tAqX -d tienda -c "$1" 2>/dev/null; }

echo "== Lab 107 · migración de total (céntimos -> euros) =="

# 1) ¿Existe la columna y es numeric?
TYPE=$(Q "SELECT data_type FROM information_schema.columns WHERE table_name='pedidos' AND column_name='total_eur'")
if [ "$TYPE" = "numeric" ]; then ok "existe pedidos.total_eur de tipo numeric."
else no "falta la columna total_eur numeric (añádela nullable primero)."; fi

# 2) ¿NOT NULL?
NN=$(Q "SELECT attnotnull FROM pg_attribute WHERE attrelid='pedidos'::regclass AND attname='total_eur'")
[ "$NN" = "t" ] && ok "total_eur es NOT NULL." || no "total_eur todavía admite NULL."

# 3) Backfill completo y correcto.
BAD=$(Q "SELECT count(*) FROM pedidos WHERE total_eur IS DISTINCT FROM round(total/100.0,2)")
[ "$BAD" = "0" ] && ok "todas las filas tienen total_eur = total/100." \
  || no "$BAD filas con total_eur mal o sin rellenar."

# 4) Las filas nuevas se rellenan solas (prueba insertando por la API).
PID=$(curl -s -X POST http://127.0.0.1:8080/checkout | jq -r '.pedido' 2>/dev/null)
if [ -n "$PID" ] && [ "$PID" != "null" ]; then
  sleep 1
  NV=$(Q "SELECT total_eur FROM pedidos WHERE id=$PID")
  EXP=$(Q "SELECT round(total/100.0,2) FROM pedidos WHERE id=$PID")
  if [ -n "$NV" ] && [ "$NV" = "$EXP" ]; then
    ok "un pedido NUEVO (id $PID) recibió total_eur automáticamente."
  else
    no "el pedido nuevo (id $PID) quedó con total_eur='$NV' (esperado '$EXP'): sin sincronía, pierdes los pedidos hechos durante la migración."
  fi
else
  no "la API no aceptó un checkout de prueba (¿está viva shop-api?)."
fi

# 5) API viva.
HC=$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/health)
[ "$HC" = "200" ] && ok "la API responde /health 200." || no "la API no responde (/health=$HC)."

echo "Resultado: $pass ok, $fail pend."
if [ "$fail" -eq 0 ]; then
  echo "🎉 Lab 107 resuelto. Migración online correcta."
  touch /tmp/.tclab-solved; exit 0
fi
echo "Aún no. Revisa la GUIA: expand/contract, backfill por lotes y sincronía de filas nuevas."
exit 1
