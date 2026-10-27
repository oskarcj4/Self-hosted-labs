#!/usr/bin/env bash
# BLUE: ¿cerrado el traversal y el bypass de X-Admin, sin romper la descarga?
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
B=http://127.0.0.1:8080

echo "== Lab 106 · BLUE (traversal + autorizacion) =="
/usr/local/bin/app-apply >/dev/null 2>&1 || true
sleep 1

[ "$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 $B/)" = 200 ] \
  && ok "la web publica (/) responde 200." || no "/ deberia seguir en 200."

# Traversal cerrado: no se lee el fichero privado.
T=$(curl -s --max-time 5 "$B/download?file=../private/user.flag")
echo "$T" | grep -q 'TCLAB{' \
  && no "/download sigue permitiendo path traversal (lee /srv/private)." \
  || ok "/download ya no sale de /srv/docs (traversal cerrado)."

# La descarga legitima sigue funcionando.
L=$(curl -s --max-time 5 "$B/download?file=readme.txt")
echo "$L" | grep -q 'documentos publicos' \
  && ok "la descarga legitima (readme.txt) sigue funcionando." \
  || no "rompiste la descarga legitima de /srv/docs/readme.txt."

# Bypass de X-Admin cerrado.
A=$(curl -s --max-time 5 -H 'X-Admin: true' "$B/admin")
echo "$A" | grep -q 'TCLAB{' \
  && no "/admin sigue fiandose de la cabecera X-Admin (broken access control)." \
  || ok "/admin ya no se fia de X-Admin (403)."

echo "Resultado BLUE: $pass ok, $fail pend."
[ "$fail" -eq 0 ]
