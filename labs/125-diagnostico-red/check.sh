#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 125.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista

echo "== Lab 125 · Diagnóstico de red — comprobación =="
if grep -q 'Loss%' $H/mtr.txt 2>/dev/null && grep -q '10.125.2.3' $H/mtr.txt && grep -q '10.125.3.10' $H/mtr.txt; then
  ok "~/mtr.txt contiene un informe mtr completo hasta srv-app."
else
  no "~/mtr.txt debe ser un informe de mtr (mtr -rwnc 50 ...) que llegue hasta 10.125.3.10."
fi
grep -qiE '^culpable=proveedor\s*$' $H/diagnostico.txt 2>/dev/null && ok "Culpable correcto: el proveedor." \
  || no "diagnostico.txt: 'culpable=' no es correcto (¿en qué salto empieza la pérdida y se mantiene?)."
grep -qE '^salto=10\.125\.2\.3\s*$' $H/diagnostico.txt 2>/dev/null && ok "Salto correcto: 10.125.2.3 (isp-transito)." \
  || no "diagnostico.txt: 'salto=' no es el primer salto con pérdida."

S=$H/simulacion.txt
avg=$(grep -oE 'rtt min/avg/max/mdev = [0-9.]+/[0-9.]+' $S 2>/dev/null | awk -F/ '{print int($5)}')
if [ -n "$avg" ] && [ "$avg" -ge 150 ] && grep -q '10.125.1.2' $S; then
  ok "simulacion.txt: ping a r1 con el retardo simulado (media ${avg} ms)."
else
  no "~/simulacion.txt: guarda un ping a 10.125.1.2 hecho con netem activo (delay ≥ 150 ms)."
fi
if tc qdisc show dev eth0 | grep -q netem; then
  no "netem sigue activo en eth0 del lab: quítalo al terminar la prueba."
else
  ok "netem retirado de eth0 (la oficina vuelve a la normalidad)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Diagnóstico demostrado con datos."; exit 0; } || exit 1
