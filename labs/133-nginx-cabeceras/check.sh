#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 133.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
U=http://tienda.lab
code(){ curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$U$1"; }
hdr(){ curl -s -D - -o /dev/null --max-time 5 "$U$1" | tr -d '\r'; }

echo "== Lab 133 · Hardening de nginx — comprobación =="
$SUDO nginx -t >/dev/null 2>&1 && ok "nginx -t: configuración válida." || no "nginx -t falla."
bad=""
for p in /.env /.env.bak /.git/config /.git/HEAD /static/../.env; do
  c=$(code "$p"); case "$c" in 403|404) ;; *) bad="$bad $p($c)";; esac
done
[ -z "$bad" ] && ok "Ficheros ocultos bloqueados (.env, .env.bak, .git/)." || no "Siguen accesibles:$bad"
curl -s --max-time 5 $U/.env | grep -q DB_PASSWORD && no "/.env aún devuelve las credenciales." || ok "/.env no filtra credenciales."
[ "$(code /.well-known/security.txt)" = 200 ] && ok "/.well-known/security.txt sigue publicado." || no "Has bloqueado también /.well-known/ (debe seguir respondiendo 200)."
[ "$(code /)" = 200 ] && [ "$(code /static/app.js)" = 200 ] && ok "La web y /static/ siguen funcionando." || no "La web o /static/ ya no responden 200."

H=$(hdr /)
echo "$H" | grep -qiE '^x-frame-options: *(deny|sameorigin)' && ok "X-Frame-Options presente." || no "Falta X-Frame-Options (DENY o SAMEORIGIN) en /."
echo "$H" | grep -qiE "^content-security-policy:.*(default-src|frame-ancestors)" && ok "Content-Security-Policy presente." || no "Falta Content-Security-Policy (con default-src) en /."
echo "$H" | grep -qiE '^x-content-type-options: *nosniff' && ok "X-Content-Type-Options: nosniff." || no "Falta X-Content-Type-Options: nosniff en /."
E=$(hdr /no-existe-133)
echo "$E" | grep -qiE '^x-content-type-options: *nosniff' && echo "$E" | grep -qi '^x-frame-options' \
  && ok "Las cabeceras salen también en respuestas de error (always)." || no "En un 404 no salen las cabeceras: añade 'always'."
echo "$E" | grep -qi '^server: nginx/' && no "La cabecera Server sigue mostrando la versión (server_tokens)." || ok "Server no muestra la versión."

C=$(hdr /cuenta/login | grep -i '^set-cookie:')
[ -n "$C" ] || no "/cuenta/login ya no envía la cookie de sesión."
echo "$C" | grep -qi 'httponly' && ok "Cookie con HttpOnly." || no "La cookie de sesión no lleva HttpOnly."
echo "$C" | grep -qi 'secure' && ok "Cookie con Secure." || no "La cookie de sesión no lleva Secure."
echo "$C" | grep -qiE 'samesite=(lax|strict)' && ok "Cookie con SameSite." || no "La cookie de sesión no lleva SameSite=Lax/Strict."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Informe de pentest cerrado."; exit 0; } || exit 1
