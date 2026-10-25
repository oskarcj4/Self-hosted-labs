#!/usr/bin/env bash
# BLUE: ¿cerraste el SSRF sin romper el acceso a la API legítima?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
F(){ curl -s -G "http://127.0.0.1:8080/fetch" --data-urlencode "url=$1"; }
real=$(cat /opt/lab/.flag 2>/dev/null)

echo "== Lab 99 · BLUE (arreglo) =="

# 1) El destino legítimo sigue alcanzable.
F "http://api.internal:8090/status" | grep -qi 'status: ok' \
  && ok "El fetcher sigue llegando a http://api.internal:8090/status." \
  || no "El fetcher ya no alcanza la API legítima: el arreglo la rompió."

# 2) SSRF a destinos internos: bloqueado y sin flag.
leaked=0
for u in "http://127.0.0.1:9000/flag" "http://localhost:9000/flag" \
         "http://api.internal:9000/flag" "http://127.0.0.1:8080/fetch?url=x"; do
  r=$(F "$u")
  [ -n "$real" ] && grep -qF "$real" <<<"$r" && leaked=1
done
[ "$leaked" -eq 0 ] && ok "El fetcher ya no alcanza el metadata interno (:9000) ni filtra la flag." \
  || no "Todavía se puede llegar al servicio interno vía el fetcher (SSRF abierto)."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
