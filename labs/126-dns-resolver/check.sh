#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 126.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista
val(){ grep -E "^$1=" $H/dns.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r' | sed 's/\.$//'; }

echo "== Lab 126 · DNS y resolvers — comprobación =="
[ "$(val resolver_actual)" = 10.126.0.99 ] && ok "Resolver original identificado (10.126.0.99)." || no "dns.txt: resolver_actual no es el que usaba el puesto."
[ "$(val portal_falso)" = 10.126.0.66 ] && ok "Respuesta falsa identificada." || no "dns.txt: portal_falso no es lo que respondía ese resolver."
[ "$(val portal_real)" = 10.126.0.80 ] && ok "IP real del portal (preguntando con @10.126.0.53)." || no "dns.txt: portal_real no coincide con el DNS oficial."
[ "$(val nombre_25)" = backup-nas.empresa.lab ] && ok "Resolución inversa correcta (dig -x)." || no "dns.txt: nombre_25 incorrecto (resolución inversa)."

ns=$(awk '/^nameserver/{print $2; exit}' /etc/resolv.conf)
[ "$ns" = 10.126.0.53 ] && ok "/etc/resolv.conf usa el DNS oficial." || no "/etc/resolv.conf sigue usando $ns como primer nameserver."
grep -q '10.126.0.99' /etc/resolv.conf && no "10.126.0.99 sigue en /etc/resolv.conf (también como secundario)." || ok "El resolver falso ya no aparece en resolv.conf."
[ "$(getent hosts portal.empresa.lab | awk '{print $1}')" = 10.126.0.80 ] && ok "El sistema resuelve el portal a su IP real." || no "getent hosts portal.empresa.lab no da 10.126.0.80."

D=$H/dnssec.txt
if grep -qE 'flags:[^;]* ad[ ;]' $D 2>/dev/null && grep -q 'RRSIG' $D && grep -q '10.126.0.80' $D; then
  ok "dnssec.txt muestra la respuesta validada (flag ad + RRSIG)."
else
  no "~/dnssec.txt: guarda 'dig +dnssec portal.empresa.lab' contra el DNS oficial (debe salir el flag ad y RRSIG)."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Resolver corregido y respuestas verificadas."; exit 0; } || exit 1
