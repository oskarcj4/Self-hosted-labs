#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
q(){ runuser -u postgres -- psql -p "$1" -d tienda -tAc "$2" 2>/dev/null; }

echo "== Lab 176 · PostgreSQL PITR — comprobación =="

TA=$(cat /opt/lab/.t_antes); TB=$(cat /opt/lab/.t_borrado)
RT=$(grep -E '^\s*recovery_target_time\s*=' /home/analista/incidente/pitr.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d "'\"" | sed 's/^ *//; s/ *$//')
RTE=$(date -d "$RT" +%s 2>/dev/null || echo 0)
if [ "$RTE" -ge "$TA" ] && [ "$RTE" -lt "$TB" ]; then
  ok "recovery_target_time ($RT) cae entre los pedidos de la mañana y el DELETE."
else
  no "~/incidente/pitr.txt: recovery_target_time='$RT' no está justo antes del DELETE."
fi

R=$(q 5433 "SELECT count(*) || ' ' || sum(total) FROM pedidos")
if [ "$R" = "$(cat /opt/lab/.perdidos)" ] && [ "$(q 5433 'SELECT pg_is_in_recovery()')" = f ]; then
  ok "La instancia de 5433 tiene el estado justo antes del DELETE ($R) y está promovida."
elif [ "$R" = "$(cat /opt/lab/.perdidos)" ]; then
  ok "La instancia de 5433 tiene el estado justo antes del DELETE ($R)."
else
  no "Instancia restaurada en 5433: pedidos='${R:-sin conexión}' (esperado $(cat /opt/lab/.perdidos))."
fi

read -r PN PS < /opt/lab/.perdidos; read -r NN NS < /opt/lab/.nuevos
P=$(q 5432 "SELECT count(*) || ' ' || sum(total) FROM pedidos")
WANT_N=$((PN + NN)); WANT_S=$(python3 -c "print(f'{$PS + $NS:.2f}')")
DUP=$(q 5432 "SELECT count(*) FROM (SELECT id FROM pedidos GROUP BY id HAVING count(*) > 1) d")
NEWOK=$(q 5432 "SELECT count(*) FROM pedidos WHERE cliente LIKE 'despues-%'")
if [ "$P" = "$WANT_N $WANT_S" ] && [ "$NEWOK" = "$NN" ] && [ "${DUP:-1}" = 0 ]; then
  ok "Producción: los $PN pedidos borrados han vuelto y siguen los $NN posteriores ($P)."
else
  no "Producción tiene '$P' (esperado '$WANT_N $WANT_S', con los $NN pedidos 'despues-*')."
fi

if systemctl is-active -q postgresql@15-main && [ "$(q 5432 "SHOW archive_mode")" = on ]; then
  ok "Producción sigue en marcha y con el archivo de WAL activo."
else
  no "Producción (postgresql@15-main) parada o con archive_mode desactivado."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Pedidos recuperados al segundo, sin parar producción."; exit 0; } || exit 1
