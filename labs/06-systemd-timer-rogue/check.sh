#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 06. Sale 0 cuando la unidad rogue y su timer desaparecen.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 06 — comprobación =="

if systemctl list-unit-files 2>/dev/null | grep -q 'sys-health'; then
  no "systemd todavía conoce las unidades 'sys-health' (deshabilítalas y borra los archivos)."
else
  ok "systemd ya no conoce ninguna unidad 'sys-health'."
fi

if [ -e /etc/systemd/system/sys-health.service ] || [ -e /etc/systemd/system/sys-health.timer ]; then
  no "Quedan archivos de unidad en /etc/systemd/system (sys-health.service/.timer)."
else
  ok "Los archivos de unidad rogue fueron borrados."
fi

if systemctl is-active --quiet sys-health.timer 2>/dev/null; then
  no "El timer sys-health.timer sigue activo."
else
  ok "El timer sys-health.timer no está activo."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Persistencia systemd erradicada. ¡Lab 06 resuelto!"; exit 0; } || exit 1
