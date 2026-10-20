#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 09.
F=/home/analista/hallazgos.txt
IP="91.219.236.12"
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 09 — comprobación =="

if [ ! -f "$F" ]; then
  echo "  [✗] No existe ~/hallazgos.txt. Escribe tu informe ahí."; exit 1
fi

if grep -q "$IP" "$F"; then
  ok "Recuperaste la IP del intruso ($IP)."
else
  no "Falta la IP correcta del intruso en el informe."
fi

if grep -qiE 'auth\.log\.1|rotad|history|historial|wtmp|last' "$F"; then
  ok "Documentaste la fuente alternativa de la evidencia."
else
  no "Indica de qué fuente recuperaste la IP (p.ej. auth.log.1 o el historial)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Evidencia reconstruida. ¡Lab 09 resuelto!"; exit 0; } || exit 1
