#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
as_an(){ if [ "$(id -u)" = 0 ]; then su -s /bin/bash analista -c "$1"; else bash -c "$1"; fi; }
P=/home/analista/trace-ci
TOKEN='tclab-trace-token-do-not-log'
B64=$(printf '%s' "$TOKEN" | base64)
T=$(mktemp -d /tmp/rt94.XXXXXX); chmod 755 "$T"
leaks(){ grep -rlF -e "$TOKEN" -e "$B64" "$@" 2>/dev/null; }

echo "== Lab 94 · xtrace y secretos — comprobación =="

x=$(grep -RnE 'set[[:space:]]+-[a-zA-Z]*x|-o[[:space:]]+xtrace|bash[[:space:]]+-[a-zA-Z]*x|SHELLOPTS|BASH_XTRACEFD' \
      "$P/run-ci.sh" "$P/jobs" 2>/dev/null | head -3)
[ -z "$x" ] && ok "Sin xtrace en run-ci.sh ni jobs/ (tampoco escondido en set -eux…)." \
  || { no "Sigue habiendo xtrace:"; sed 's/^/      /' <<<"$x"; }

if [ -f "$P/secrets/deploy_token" ] && grep -q "^DEPLOY_TOKEN=$TOKEN" "$P/secrets/deploy_token"; then
  ok "El secreto sigue en secrets/deploy_token."
else
  no "No borres ni cambies el token: el problema es el log, no el secreto."
fi

# ---------- CI real ----------
if as_an "cd '$P' && ./run-ci.sh" >"$T/ci.out" 2>&1; then
  ok "./run-ci.sh termina 0."
else
  no "./run-ci.sh falló:"; tail -n 8 "$T/ci.out" | sed 's/^/      /'
fi
grep -q 'push ok' "$P/logs/last-run.log" 2>/dev/null \
  && ok "El deploy sigue autenticando (push ok)." || no "No aparece 'push ok': el deploy ya no funciona."
[ -f "$P/artifacts/ok.txt" ] && ok "Hay artifacts/ok.txt." || no "Falta artifacts/ok.txt."

l=$(leaks "$P/logs/last-run.log" "$T/ci.out")
[ -z "$l" ] && ok "El log no contiene el token (ni en claro ni en base64)." \
  || no "El log filtra el token (en claro o en base64)."
l=$(leaks "$P/artifacts")
[ -z "$l" ] && ok "Los artefactos públicos no contienen el token." \
  || no "El token está en artefactos: ${l//$P\//}"

# ---------- defensa en profundidad: un job nuevo que hace echo del secreto ----------
cp -r "$P" "$T/p"
printf '#!/usr/bin/env bash\necho "leak: $DEPLOY_TOKEN"\n' > "$T/p/jobs/99-leak.sh"
chown -R analista:analista "$T/p" 2>/dev/null
as_an "cd '$T/p' && ./run-ci.sh" >"$T/leak.out" 2>&1
if ! grep -q '^leak: ' "$T/p/logs/last-run.log" 2>/dev/null; then
  no "run-ci.sh no ejecuta todos los jobs/*.sh (o se come su salida)."
elif grep -qF "$TOKEN" "$T/p/logs/last-run.log" "$T/leak.out"; then
  no "Un job con echo \$DEPLOY_TOKEN sigue filtrando: el runner no enmascara secretos."
else
  ok "El runner enmascara el secreto aunque un job lo imprima."
fi
rm -rf "$T"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Logs y artefactos sin secretos. ¡Lab 94 resuelto!"; exit 0; } || exit 1
