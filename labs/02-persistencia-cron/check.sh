#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 02. Sale 0 si el beacon y su persistencia desaparecieron.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 02 — comprobación =="

# Obj 3: persistencia en cron eliminada
if ls /etc/cron.d/ 2>/dev/null | grep -q . && grep -rqs "respawn\|system-update" /etc/cron.d/ ; then
  no "Sigue existiendo la tarea de persistencia en /etc/cron.d/."
else
  ok "La persistencia en cron fue eliminada."
fi

# Obj 4: binario impostor borrado
if [ -e /tmp/system-update ]; then
  no "El binario impostor /tmp/system-update todavía existe."
else
  ok "El binario impostor /tmp/system-update fue borrado."
fi

# Obj 1/4: proceso muerto
if pgrep -f /tmp/system-update >/dev/null 2>&1; then
  no "El proceso impostor sigue vivo (pgrep lo encuentra)."
else
  ok "El proceso impostor no está corriendo."
fi

# Obj 5: puerto 4444 cerrado
if ss -tlnp 2>/dev/null | grep -q ':4444 '; then
  no "El puerto 4444 sigue en escucha."
else
  ok "El puerto 4444 ya no escucha."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
if [ "$fail" -eq 0 ]; then
  echo "🎉 Beacon erradicado y persistencia desarmada. ¡Lab 02 resuelto!"
  echo "   (Tip: vuelve a correr el check en 60s para confirmar que NO revive.)"
  exit 0
else
  exit 1
fi
