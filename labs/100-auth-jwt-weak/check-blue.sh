#!/usr/bin/env bash
# BLUE: ¿rechazas los tokens forjados sin romper el login legítimo?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
real=$(cat /opt/lab/.flag 2>/dev/null)
U=http://127.0.0.1:8080

echo "== Lab 100 · BLUE (arreglo) =="

# 1) Login legítimo + /me sigue funcionando.
tok=$(curl -s --data-urlencode "user=ana" --data-urlencode "password=Primavera2024" "$U/login" | sed -n 's/^token=//p')
if [ -n "$tok" ] && curl -s -H "Authorization: Bearer $tok" "$U/me" | grep -q 'role=user'; then
  ok "Login de ana + /me siguen funcionando con su token firmado."
else
  no "El flujo legítimo (login/me) se rompió."
fi

# 2) Token forjado con alg:none y rol admin: rechazado, sin flag.
forged=$(python3 - <<'PY'
import base64, json
b=lambda o: base64.urlsafe_b64encode(json.dumps(o).encode()).rstrip(b"=").decode()
print(b({"alg":"none","typ":"JWT"})+"."+b({"user":"x","role":"admin"})+".")
PY
)
r=$(curl -s -H "Authorization: Bearer $forged" "$U/admin")
if grep -qF "$real" <<<"$r"; then
  no "El token alg:none con rol admin todavía entra en /admin."
else
  ok "El token forjado (alg:none) ya no accede a /admin."
fi

# 3) Token con firma manipulada: rechazado.
if [ -n "$tok" ]; then
  bad="${tok%.*}.AAAAAAAAAAAAAAAAAAAAAAAAAAA"
  curl -s -H "Authorization: Bearer $bad" "$U/me" | grep -q 'role=' \
    && no "Acepta un token con firma inválida." \
    || ok "Un token con firma manipulada se rechaza."
fi

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
