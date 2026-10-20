#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 11.
P=/data/.payload
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 11 — comprobación =="

if [ -e "$P" ]; then
  if lsattr "$P" 2>/dev/null | grep -q 'i'; then
    no "El payload sigue inmutable (quita el atributo con 'chattr -i')."
  else
    no "Quitaste el atributo pero el payload aún existe (bórralo con 'rm')."
  fi
else
  ok "El payload inmutable fue neutralizado y borrado."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Archivo inmutable erradicado. ¡Lab 11 resuelto!"; exit 0; } || exit 1
