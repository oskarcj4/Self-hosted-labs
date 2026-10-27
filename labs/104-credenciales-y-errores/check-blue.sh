#!/usr/bin/env bash
# BLUE: ¿contraseña fuerte y errores callados, sin romper el panel? HTTP local.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
B=http://127.0.0.1:8080
code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$@"; }

echo "== Lab 104 · BLUE (credenciales + errores) =="
/usr/local/bin/app-apply >/dev/null 2>&1 || true
sleep 1

[ "$(code $B/)" = 200 ] && ok "web publica (/) responde 200." \
  || no "la web publica (/) deberia seguir en 200."

# Credencial por defecto ya no entra.
[ "$(code -u admin:admin $B/panel)" != 200 ] && ok "admin:admin ya no entra en /panel." \
  || no "/panel sigue aceptando la contraseña por defecto admin:admin."

# La contraseña actual no es una débil conocida.
PW=$(python3 -c 'import json;print(json.load(open("/etc/panel/config.json")).get("panel_pass",""))' 2>/dev/null)
case "$PW" in
  admin|password|1234|12345|123456|root|changeme|panel|"" )
    no "la contraseña del panel sigue siendo débil ('$PW'): pon una fuerte." ;;
  * )
    if [ "${#PW}" -ge 10 ]; then ok "la contraseña del panel es fuerte."
    else no "la contraseña del panel es corta (${#PW} car.): usa 12+ aleatorios."; fi ;;
esac

# El panel sigue funcionando con la contraseña buena.
if [ -n "$PW" ]; then
  [ "$(code -u "admin:$PW" $B/panel)" = 200 ] && ok "/panel funciona con la contraseña nueva." \
    || no "rompiste /panel para la credencial legitima."
fi

# /debug ya no filtra la bandera.
BODY=$(curl -s --max-time 5 "$B/debug?q=x")
echo "$BODY" | grep -q 'TCLAB{' && no "/debug sigue filtrando la bandera (errores verbosos)." \
  || ok "/debug ya no filtra secretos (errores callados)."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
