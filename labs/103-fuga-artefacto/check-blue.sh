#!/usr/bin/env bash
# BLUE: ¿cerraste las dos vias sin romper lo legitimo? HTTP a localhost.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
B=http://127.0.0.1:8080
code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1"; }

echo "== Lab 103 · BLUE (fuga de artefacto + debug) =="
/usr/local/bin/app-apply >/dev/null 2>&1 || true
sleep 1

[ "$(code $B/)" = 200 ] && ok "web publica (/) responde 200." \
  || no "la web publica (/) deberia seguir en 200."
[ "$(code $B/backup/)" != 200 ] && ok "listado /backup/ cerrado." \
  || no "/backup/ sigue sirviendo el listado."
[ "$(code $B/backup/app.py.bak)" != 200 ] && ok "fuente .bak ya no se descarga." \
  || no "/backup/app.py.bak sigue accesible."
[ "$(code "$B/admin")" != 200 ] && ok "/admin sin token: denegado (debug off)." \
  || no "/admin entrega sin token: debug sigue activado."

AT=$(python3 -c 'import json;print(json.load(open("/srv/app/secrets.json"))["admin_token"])' 2>/dev/null)
if [ -n "$AT" ]; then
  [ "$(code "$B/admin?token=$AT")" = 200 ] && ok "/admin con token valido sigue funcionando." \
    || no "rompiste /admin para el token legitimo (solo quita el debug, no mates el endpoint)."
fi
echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
