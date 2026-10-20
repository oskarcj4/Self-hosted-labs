#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 18.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }

echo "== Lab 18 — comprobación =="
R="$(iptables -S INPUT 2>/dev/null)"

echo "$R" | grep -qE '^-P INPUT DROP' \
  && ok "La política por defecto de INPUT es DROP." \
  || no "La política por defecto de INPUT debe ser DROP."

echo "$R" | grep -qE '\-i lo -j ACCEPT' \
  && ok "Se acepta el tráfico de loopback." \
  || no "Falta aceptar el tráfico de loopback (-i lo)."

echo "$R" | grep -qiE 'ESTABLISHED' \
  && ok "Se acepta el tráfico de conexiones establecidas." \
  || no "Falta aceptar ESTABLISHED,RELATED."

for p in 22 80 443; do
  echo "$R" | grep -qE "\-\-dport $p -j ACCEPT" \
    && ok "Puerto $p/tcp permitido." \
    || no "Falta permitir el puerto $p/tcp."
done

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Firewall base en pie. ¡Lab 18 resuelto!"; exit 0; } || exit 1
