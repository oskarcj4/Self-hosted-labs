#!/usr/bin/env bash
# BLUE: ¿el proxy ya no llega al metadata interno, pero el health legítimo sí?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
B=http://127.0.0.1:8080

echo "== Lab 105 · BLUE (SSRF a metadatos) =="
/usr/local/bin/app-apply >/dev/null 2>&1 || true
sleep 1

[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $B/)" = 200 ] \
  && ok "la web publica (/) responde 200." || no "/ deberia seguir en 200."

# El SSRF al metadata interno ya no filtra banderas.
U=$(curl -s --max-time 5 "$B/fetch?url=http://127.0.0.1:8081/user")
R=$(curl -s --max-time 5 "$B/fetch?url=http://127.0.0.1:8081/root")
echo "$U$R" | grep -q 'TCLAB{' \
  && no "/fetch sigue alcanzando el metadata interno (127.0.0.1:8081): SSRF abierto." \
  || ok "/fetch ya no alcanza el metadata interno (SSRF cerrado)."

# Un destino interno arbitrario tambien se bloquea.
AP=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$B/fetch?url=http://127.0.0.1:8081/")
[ "$AP" = 403 ] && ok "destinos no permitidos devuelven 403." \
  || no "destino interno no bloqueado (codigo $AP): usa allowlist + restrict_targets."

# El health legitimo sigue funcionando.
HL=$(curl -s --max-time 5 "$B/fetch?url=http://status.lab:8080/health")
echo "$HL" | grep -q 'OK' \
  && ok "el health legitimo (status.lab) sigue funcionando." \
  || no "rompiste el health legitimo: deja http://status.lab:8080/health en la allowlist."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
