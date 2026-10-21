#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 65.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
B=/srv/shop; R=$B/releases
R42=$R/2026-10-12_1105-r42; R43=$R/2026-10-20_0915-r43

echo "== Lab 65 · Deploy fallido y rollback — comprobación =="

if [ -L $B/current ]; then
  ok "/srv/shop/current sigue siendo un enlace simbólico (no una copia)."
else
  no "/srv/shop/current ya no es un enlace simbólico: el layout de releases depende de él."
fi
tgt=$(readlink -f $B/current)
[ "$tgt" = "$R42" ] && ok "current apunta a la r42." \
  || no "current apunta a '${tgt#$R/}', no a la r42 (2026-10-12_1105-r42)."

if [ -d "$R43" ] && [ "$(ls -A "$R43" | LC_ALL=C sort | tr '\n' ' ')" = "VERSION app.py uploads " ] \
   && cmp -s "$R43/app.py" "$R42/app.py"; then
  ok "La r43 sigue intacta para el análisis."
else
  no "La r43 se borró o cambió ($(ls -A "$R43" 2>/dev/null | tr '\n' ' ')). Ojo: 'ln -sf' sin -n mete el enlace DENTRO del directorio."
fi
stray=$(ls -A $B | grep -vxE 'current|releases|shared')
[ -z "$stray" ] && ok "No quedan restos en /srv/shop." || no "Restos en /srv/shop: $stray"

echo "  (observando shop 5 s...)"
p0=$(systemctl show -p MainPID --value shop); sleep 5; p1=$(systemctl show -p MainPID --value shop)
if systemctl is-active --quiet shop && [ "$p0" = "$p1" ] && [ "$p1" != 0 ]; then
  ok "shop activo y estable."
else
  no "shop no está activo y estable ($(systemctl is-active shop))."
fi
cwd=$(sudo -n readlink "/proc/$p1/cwd" 2>/dev/null)
[ "$cwd" = "$R42" ] && ok "El proceso en marcha corre desde la r42 (se reinició tras el cambio)." \
  || no "El proceso en marcha corre desde '${cwd:-?}': ¿reiniciaste shop tras cambiar current?"

h=$(curl -s --max-time 3 http://127.0.0.1:8500/health)
echo "$h" | grep -q '^ok r42' && ok "/health: $h" || no "/health no responde 'ok r42' (responde: ${h:-nada})."

[ "$(ls $R42/uploads/ 2>/dev/null | wc -l)" -eq 12 ] && ok "La r42 ve los 12 ficheros de shared/uploads." \
  || no "La r42 ya no ve shared/uploads."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Rollback limpio a la r42, con la r43 guardada para el análisis."; exit 0; } || exit 1
