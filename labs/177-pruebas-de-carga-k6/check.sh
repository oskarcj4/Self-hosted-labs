#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
P=/home/analista/carga/prueba.js
export K6_NO_USAGE_REPORT=true

echo "== Lab 177 · Pruebas de carga con k6 — comprobación =="

if [ -f "$P" ] && grep -q 'stages' "$P" && grep -qE '[^0-9]50[^0-9]' "$P" \
   && grep -qE "http_req_duration.*p\(95\)\s*<\s*300" "$P" && grep -qE "http_req_failed.*rate\s*<\s*0?\.01" "$P" \
   && grep -q '/productos' "$P" && grep -q '/buscar' "$P" \
   && runuser -u analista -- k6 inspect "$P" >/dev/null 2>&1; then
  ok "~/carga/prueba.js: etapas hasta 50 VUs, umbrales p95<300 ms y errores<1 %, ambas rutas."
else
  no "~/carga/prueba.js necesita stages hasta 50 VUs, thresholds (p(95)<300, rate<0.01) y pedir /productos y /buscar."
fi

I=$(tr 'A-Z' 'a-z' < /home/analista/carga/informe.txt 2>/dev/null)
if echo "$I" | grep -qE 'hilo|thread|concurren|secuencial|una a una|de una en una' && echo "$I" | grep -qE 'índice|indice|index'; then
  ok "~/carga/informe.txt explica los dos cuellos (servidor sin concurrencia y búsqueda sin índice)."
else
  no "~/carga/informe.txt debe explicar los dos cuellos de botella y su arreglo."
fi

if sqlite3 /home/analista/catalogo/catalogo.db "EXPLAIN QUERY PLAN SELECT count(*), avg(precio) FROM productos WHERE categoria = 'cat-001'" 2>/dev/null | grep -qi 'USING .*INDEX'; then
  ok "La búsqueda por categoría usa un índice."
else
  no "La búsqueda por categoría recorre la tabla entera (EXPLAIN QUERY PLAN: SCAN)."
fi

OUT=$(runuser -u analista -- k6 run --quiet --no-color /opt/lab/referencia.js 2>&1); rc=$?
P95=$(echo "$OUT" | grep -E '^\s*http_req_duration' | head -1 | grep -oE 'p\(95\)=[0-9.]+[a-zµ]+' | cut -d= -f2)
FR=$(echo "$OUT" | grep -E '^\s*http_req_failed' | head -1 | grep -oE '[0-9.]+%' | head -1)
if [ $rc = 0 ]; then
  ok "Prueba de referencia (50 VUs, 20 s): p95=$P95, errores=$FR. Umbrales OK."
else
  no "Prueba de referencia (50 VUs, 20 s): p95=${P95:-?}, errores=${FR:-?}. No cumple el objetivo."
fi

OUT2=$(cd /home/analista/carga && runuser -u analista -- k6 run --quiet --no-color "$P" 2>&1); rc2=$?
if [ $rc2 = 0 ]; then
  ok "Tu prueba (~/carga/prueba.js) pasa todos sus umbrales."
else
  no "Tu prueba no pasa sus umbrales (rc=$rc2)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Listo para el Black Friday, y con la prueba para demostrarlo."; exit 0; } || exit 1
