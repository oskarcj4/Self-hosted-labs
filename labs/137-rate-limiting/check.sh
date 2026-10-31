#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 137.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista

echo "== Lab 137 · Rate limiting en nginx — comprobación =="
grep -qE '^ip_bot=10\.137\.0\.66\s*$' $H/limite.txt 2>/dev/null && ok "IP del bot identificada en el access.log." || no "limite.txt: ip_bot= no es la IP que más pide /api/login."
$SUDO nginx -t >/dev/null 2>&1 && ok "nginx -t: configuración válida." || no "nginx -t falla."
$SUDO nginx -T 2>/dev/null | grep -qE '^\s*limit_req_zone' && ok "limit_req_zone definido." || no "Falta limit_req_zone."
$SUDO nginx -T 2>/dev/null | grep -qE '^\s*limit_conn_zone' && ok "limit_conn_zone definido." || no "Falta limit_conn_zone."

burst(){ seq 1 "$2" | xargs -P 25 -I{} curl -s -o /dev/null -w '%{http_code}\n' --max-time 5 "http://127.0.0.1$1" | sort | uniq -c; }
B=$(burst /api/login 60)
n429=$(echo "$B" | awk '$2==429{print $1}'); n401=$(echo "$B" | awk '$2==401{print $1}')
[ "${n429:-0}" -ge 10 ] && [ "${n401:-0}" -ge 1 ] && ok "Ráfaga de 60 a /api/login: ${n401} pasan y ${n429} reciben 429." \
  || no "Ráfaga de 60 a /api/login: esperaba algunos 401 y muchos 429 (obtuve: $(echo $B))."
S=$(burst /static/app.js 60)
[ "$(echo "$S" | awk '$2==200{print $1}')" = 60 ] && ok "/static/ sin límite (60/60 → 200)." || no "Los estáticos también se limitan: $(echo $S)."
$SUDO tail -n 400 /var/log/nginx/access.log | grep '^10\.137\.0\.66 ' | grep -q '" 429 ' && ok "El bot ya recibe 429 (access.log)." || no "En el access.log el bot no recibe 429."

grep -q 'Status code distribution' $H/hey-antes.txt 2>/dev/null && ! grep -qE '\[429\]' $H/hey-antes.txt \
  && ok "hey-antes.txt: medición sin límite." || no "~/hey-antes.txt debe ser una salida de hey hecha antes de limitar (sin 429)."
grep -q 'Status code distribution' $H/hey-despues.txt 2>/dev/null && grep -qE '\[429\]' $H/hey-despues.txt \
  && ok "hey-despues.txt: se ven los 429." || no "~/hey-despues.txt debe ser una salida de hey con el límite activo (con 429)."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Login protegido contra fuerza bruta y abuso."; exit 0; } || exit 1
