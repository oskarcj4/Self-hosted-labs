#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 22.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 22 — comprobación =="

if auditctl -l 2>/dev/null | grep -q 'passwd_changes'; then
  ok "La regla de auditoría sobre /etc/passwd está activa (key passwd_changes)."
else
  no "Falta la regla activa que vigile /etc/passwd con key 'passwd_changes'."
fi

if ausearch -k passwd_changes 2>/dev/null | grep -q .; then
  ok "ausearch encuentra eventos de cambios en /etc/passwd."
else
  no "ausearch no encuentra eventos (provoca un cambio en /etc/passwd y reintenta)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Auditoría activa. ¡Lab 22 resuelto!"; exit 0; } || exit 1
