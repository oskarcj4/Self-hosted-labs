#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 59. Consulta la BD real: datos, estructura y permisos.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
q(){ if [ "$(id -u)" -eq 0 ]; then su postgres -c "psql -d tienda -tAc \"$1\"" 2>/dev/null
     else sudo -n -u postgres psql -d tienda -tAc "$1" 2>/dev/null; fi; }

echo "== Lab 59 · Restaurar tras un borrado — comprobación =="

if [ "$(systemctl is-active postgresql)" != active ]; then
  no "PostgreSQL no está en marcha."
  echo "Resultado: $pass superados, $fail pendientes."; exit 1
fi

n=$(q "select count(*) from pedidos")
if [ "$n" = 2000 ]; then ok "pedidos restaurada con sus 2000 filas."
else no "pedidos tiene '${n:-no existe}' filas (deben ser las 2000 del backup)."; fi

same=$(q "select (select coalesce(sum(total),0) from pedidos) = (select sum(((g*37)%500)+0.99) from generate_series(1,2000) g)")
[ "$same" = t ] && ok "Los importes de pedidos coinciden con el backup." \
  || no "Los importes de pedidos no coinciden con los del backup."

c=$(q "select count(*) from clientes")
nuevos=$(q "select count(*) from clientes where email in ('ana.ruiz@ejemplo.com','luis.gil@ejemplo.com','marta.sanz@ejemplo.com','iker.vega@ejemplo.com','noa.prieto@ejemplo.com')")
if [ "$c" = 505 ] && [ "$nuevos" = 5 ]; then ok "clientes conserva los 505, incluidos los 5 de hoy."
else no "clientes tiene ${c:-?} filas y ${nuevos:-0}/5 de los clientes de hoy: restauraste encima de datos buenos."; fi

pk=$(q "select count(*) from pg_constraint where conrelid='pedidos'::regclass and contype='p'")
fk=$(q "select count(*) from pg_constraint where conrelid='pedidos'::regclass and contype='f' and confrelid='clientes'::regclass")
ix=$(q "select count(*) from pg_indexes where tablename='pedidos' and indexname='pedidos_cliente_idx'")
if [ "$pk" = 1 ] && [ "$fk" = 1 ] && [ "$ix" = 1 ]; then
  ok "pedidos tiene su clave primaria, su clave foránea y su índice."
else
  no "A pedidos le falta estructura (PK=${pk:-0} FK=${fk:-0} índice=${ix:-0}): no restauraste sólo los datos, ¿verdad?"
fi

nxt=$(q "select (select last_value from pedidos_id_seq) >= (select max(id) from pedidos)")
[ "$nxt" = t ] && ok "La secuencia de pedidos.id está por delante de los datos (el próximo INSERT no choca)." \
  || no "La secuencia pedidos_id_seq falta o va por detrás de max(id): el próximo pedido fallará."

owner=$(q "select tableowner from pg_tables where tablename='pedidos'")
[ "$owner" = tienda ] && ok "pedidos pertenece a 'tienda' (la app puede usarla)." \
  || no "pedidos pertenece a '${owner:-?}', no a 'tienda'."

code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:8080/health)
[ "$code" = 200 ] && ok "tienda-web /health responde 200." \
  || no "tienda-web /health responde ${code:-nada}: curl http://127.0.0.1:8080/health"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Datos restaurados sin perder los de hoy."; exit 0; } || exit 1
