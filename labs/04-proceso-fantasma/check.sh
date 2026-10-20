#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 04. Sale 0 si el proceso impostor y su binario desaparecen.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 04 — comprobación =="

# El impostor usa exactamente el nombre 'kworker' (los reales son kworker/N:M).
if pgrep -x kworker >/dev/null 2>&1; then
  no "El proceso impostor 'kworker' sigue corriendo."
else
  ok "El proceso impostor 'kworker' ya no está corriendo."
fi

if [ -e /tmp/kworker ]; then
  no "El binario impostor /tmp/kworker todavía existe."
else
  ok "El binario impostor /tmp/kworker fue borrado."
fi

if [ -e /usr/local/bin/sysmon ]; then
  no "El monitor amañado /usr/local/bin/sysmon sigue presente (desenmascáralo)."
else
  ok "El monitor amañado fue eliminado."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Proceso fantasma erradicado. ¡Lab 04 resuelto!"; exit 0; } || exit 1
