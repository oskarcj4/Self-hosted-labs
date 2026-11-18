#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
Q(){ runuser -u postgres -- psql -d tienda -qAtX -c "$1" 2>/dev/null; }
LOG=/var/log/trafico

echo "== Lab 220 · Migración de PostgreSQL en caliente — comprobación =="

if ! systemctl is-active -q postgresql trafico; then
  no "PostgreSQL o el tráfico de la tienda no están en marcha."
fi

# 1. Esquema final.
TIPO=$(Q "SELECT data_type FROM information_schema.columns WHERE table_name='pedidos' AND column_name='id'")
PK=$(Q "SELECT a.attname FROM pg_index i JOIN pg_attribute a ON a.attrelid=i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid='pedidos'::regclass AND i.indisprimary")
DEF=$(Q "SELECT pg_get_expr(d.adbin, d.adrelid) FROM pg_attrdef d JOIN pg_attribute a ON a.attrelid=d.adrelid AND a.attnum=d.adnum
         WHERE d.adrelid='pedidos'::regclass AND a.attname='id'")
SEQ=$(printf '%s' "$DEF" | sed -nE "s/^nextval\('([^']+)'.*/\1/p")
SEQTIPO=$([ -n "$SEQ" ] && Q "SELECT data_type FROM pg_sequences WHERE format('%I.%I', schemaname, sequencename)::regclass = '$SEQ'::regclass")
if [ "$TIPO" = bigint ] && [ "$PK" = id ]; then
  ok "pedidos.id es bigint y es la clave primaria."
else
  no "pedidos.id es '${TIPO:-?}' y la clave primaria está en '${PK:-nada}' (debe ser bigint, PK en id)."
fi
if [ -n "$SEQ" ] && [ "$SEQTIPO" = bigint ]; then
  ok "id toma su valor de la secuencia $SEQ, que es bigint."
else
  no "El default de id es '${DEF:-ninguno}' y la secuencia es '${SEQTIPO:-?}' (debe ser nextval de una secuencia bigint)."
fi
RESTOS=$(Q "SELECT string_agg(x, ', ') FROM (
  SELECT 'columna ' || attname AS x FROM pg_attribute WHERE attrelid='pedidos'::regclass AND attnum>0 AND NOT attisdropped
         AND attname NOT IN ('id','ref','cliente','total','estado','creado')
  UNION ALL SELECT 'trigger ' || tgname FROM pg_trigger WHERE tgrelid='pedidos'::regclass AND NOT tgisinternal
  UNION ALL SELECT 'índice inválido ' || indexrelid::regclass FROM pg_index WHERE indrelid='pedidos'::regclass AND NOT indisvalid) t")
NN=$(Q "SELECT attnotnull FROM pg_attribute WHERE attrelid='pedidos'::regclass AND attname='id'")
if [ -z "$RESTOS" ] && [ "$NN" = t ]; then
  ok "No quedan restos de la migración (columnas, triggers o índices inválidos)."
else
  no "Quedan restos de la migración: ${RESTOS:-id admite NULL}."
fi

# 2. Datos: ids históricos intactos y ningún pedido confirmado perdido.
read -r HIST MAL < <(Q "SELECT count(*), count(*) FILTER (WHERE id::text <> substr(ref, 2)) FROM pedidos WHERE ref LIKE 'h%'" | tr '|' ' ')
if [ "$HIST" = 3000000 ] && [ "$MAL" = 0 ]; then
  ok "Los 3 000 000 pedidos históricos siguen con su id original."
else
  no "Pedidos históricos: ${HIST:-?} (deben ser 3000000), con id cambiado: ${MAL:-?}."
fi
cp $LOG/confirmados.log /tmp/conf-220.txt && chmod 644 /tmp/conf-220.txt
read -r CONF PERD < <(runuser -u postgres -- psql -d tienda -qAtX 2>/dev/null <<'SQL' | tr '|' ' '
CREATE TEMP TABLE c (ref text);
COPY c FROM '/tmp/conf-220.txt';
ANALYZE c;
SET enable_nestloop = off;
SELECT count(*), count(*) FILTER (WHERE p.ref IS NULL) FROM c LEFT JOIN pedidos p USING (ref);
SQL
)
if [ "${CONF:-0}" -gt 0 ] && [ "$PERD" = 0 ]; then
  ok "Los $CONF pedidos que la app confirmó durante la migración están en la tabla."
else
  no "De ${CONF:-0} pedidos confirmados por la app faltan ${PERD:-?} en la tabla."
fi

# 3. Tráfico: sin errores, sin huecos y sin parar.
read -r SEG OKS ERRS LMAX HUECO < <(awk 'NR>1 && $1-p>h {h=$1-p} {p=$1; n++; o+=$2; e+=$3; if ($4>m) m=$4}
  END {print n+0, o+0, e+0, m+0, h+0}' $LOG/segundos.log)
if [ "$ERRS" = 0 ] && [ "$SEG" -ge 30 ]; then
  ok "0 errores en $SEG s de tráfico ($OKS operaciones OK, latencia máxima $LMAX ms)."
else
  no "El tráfico registra $ERRS operaciones con error (bloqueo de más de 1 s, fallo o >10 s) en $SEG s. Ver $LOG/errores.log (sudo reiniciar-tienda para reintentar)."
fi
INS=$(awk -v d=$(( $(date +%s) - 10 )) '$1>=d {i+=$5} END {print i+0}' $LOG/segundos.log)
if [ "$HUECO" -le 3 ] && [ "$INS" -gt 0 ]; then
  ok "El tráfico nunca se paró (hueco máximo ${HUECO} s) y siguen entrando pedidos ($INS en 10 s)."
else
  no "El tráfico se paró (hueco de ${HUECO} s en el registro) o no entran pedidos ($INS en los últimos 10 s)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 int -> bigint en 3 M filas, con la tienda abierta y sin un solo error."; exit 0; } || exit 1
