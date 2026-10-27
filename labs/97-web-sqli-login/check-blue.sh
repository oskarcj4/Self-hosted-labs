#!/usr/bin/env bash
# BLUE: ¿cerraste la inyección SIN romper el login legítimo?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
U=http://127.0.0.1:8080/login
post(){ curl -s -o /dev/null -w '%{http_code}' --data-urlencode "user=$1" --data-urlencode "password=$2" "$U"; }
body(){ curl -s --data-urlencode "user=$1" --data-urlencode "password=$2" "$U"; }
real=$(cat /opt/lab/.flag 2>/dev/null)

echo "== Lab 97 · BLUE (arreglo) =="

# 1) Login legítimo sigue funcionando.
b=$(body "ana" "Primavera2024")
if grep -q 'role=user' <<<"$b" && grep -q 'bienvenido=ana' <<<"$b"; then
  ok "El login legítimo (ana) sigue funcionando."
else
  no "ana/Primavera2024 ya no entra: el arreglo rompió el login."
fi

# 2) Credenciales malas se rechazan (no 500).
c=$(post "ana" "clave-mala")
[ "$c" = 401 ] && ok "Una clave incorrecta devuelve 401." \
  || no "Clave incorrecta devuelve $c (se esperaba 401)."

# 3) Inyección clásica de bypass: ya no autentica ni filtra la flag.
leaked=0
for p in "' OR '1'='1" "' OR 1=1 -- " "admin' -- " "x' UNION SELECT username,role,flag FROM users -- "; do
  r=$(body "$p" "$p")
  grep -q '^OK ' <<<"$r" && leaked=1
  [ -n "$real" ] && grep -qF "$real" <<<"$r" && leaked=1
done
[ "$leaked" -eq 0 ] && ok "Las inyecciones de prueba ya no autentican ni filtran la flag." \
  || no "Todavía se puede entrar o extraer la flag por inyección."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
