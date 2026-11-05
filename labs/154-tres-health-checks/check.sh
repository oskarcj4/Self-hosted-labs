#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 3 "localhost:8080$1" 2>/dev/null; }

echo "== Lab 154 · Tres health checks — comprobación =="

# Asegura dependencia arriba al empezar
$SUDO systemctl start allsafe-db 2>/dev/null; sleep 1

# 1) Las tres sondas existen y responden 200 con todo sano
L=$(code /livez); S=$(code /startup); R=$(code /readyz)
[ "$L" = "200" ] && ok "/livez responde 200." || no "/livez no responde 200 (es $L)."
[ "$S" = "200" ] && ok "/startup responde 200." || no "/startup no responde 200 (es $S)."
[ "$R" = "200" ] && ok "/readyz responde 200 con la base de datos arriba." || no "/readyz no responde 200 (es $R)."

# 2) Si cae la dependencia: readyz 503, livez sigue 200
$SUDO systemctl stop allsafe-db 2>/dev/null; sleep 2
R2=$(code /readyz); L2=$(code /livez)
if [ "$R2" = "503" ]; then ok "/readyz pasa a 503 cuando la base de datos cae."
else no "/readyz debería dar 503 sin base de datos (da $R2)."; fi
if [ "$L2" = "200" ]; then ok "/livez sigue en 200 aunque la dependencia esté caída."
else no "/livez no debe depender de la base de datos (da $L2)."; fi

# 3) Se recupera al volver la dependencia
$SUDO systemctl start allsafe-db 2>/dev/null; sleep 2
R3=$(code /readyz)
[ "$R3" = "200" ] && ok "/readyz vuelve a 200 cuando la base de datos regresa." || no "/readyz no se recupera (da $R3)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Liveness, readiness y startup con semántica real."; exit 0; } || exit 1
