#!/usr/bin/env bash
# BLUE: ¿cerraste la inyección de comandos sin romper la resolución legítima?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
G(){ curl -s -G "http://127.0.0.1:8080/run" --data-urlencode "host=$1"; }
real=$(cat /opt/lab/.flag 2>/dev/null)

echo "== Lab 98 · BLUE (arreglo) =="

# 1) Resolución legítima sigue funcionando.
if G "localhost" | grep -qiE '127\.0\.0\.1|::1|localhost'; then
  ok "Resolver 'localhost' sigue devolviendo resultado."
else
  no "Resolver 'localhost' ya no funciona: el arreglo rompió la herramienta."
fi

# 2) Inyección de comandos: no ejecuta nada ni filtra la flag.
leaked=0
for p in "localhost; cat /srv/app/flag.txt" "localhost\$(cat /srv/app/flag.txt)" \
         "localhost | cat /srv/app/flag.txt" "x && cat /srv/app/flag.txt" \
         "\`cat /srv/app/flag.txt\`"; do
  r=$(G "$p")
  [ -n "$real" ] && grep -qF "$real" <<<"$r" && leaked=1
done
[ "$leaked" -eq 0 ] && ok "Los metacaracteres de shell ya no ejecutan comandos ni filtran la flag." \
  || no "Todavía se puede inyectar un comando por el parámetro host."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
