#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
P=/home/analista/shop-ci
TOKEN='tclab-live-token-do-not-commit'

echo "== Lab 87 · Pipeline CI que filtra secretos — comprobación =="

[ -d "$P" ] || { no "No está ~/shop-ci"; echo "Resultado: 0 superados, 1 pendientes."; exit 1; }

if grep -nE "$TOKEN|DEPLOY_TOKEN:" "$P/pipeline.yml" >/dev/null 2>&1; then
  no "pipeline.yml todavía declara el token."
else
  ok "pipeline.yml ya no lleva el token."
fi

if grep -nE 'pull_request' "$P/pipeline.yml" >/dev/null 2>&1; then
  no "El pipeline sigue disparándose en pull_request (secretos en PRs)."
else
  ok "El pipeline ya no corre con secretos en pull_request."
fi

if grep -RIn --exclude-dir=logs --exclude-dir=secrets 'docker.sock' "$P" >/dev/null 2>&1; then
  no "Todavía hay un montaje de docker.sock en el proyecto."
else
  ok "Ningún job monta docker.sock."
fi

sec="$P/secrets/deploy_token"
if [ -f "$sec" ] && $SUDO grep -q '^DEPLOY_TOKEN=' "$sec"; then
  mode=$($SUDO stat -c '%a' "$sec" 2>/dev/null || $SUDO stat -f '%OLp' "$sec")
  echo "$mode" | grep -qE '^(400|600)$' && ok "secrets/deploy_token existe y está en $mode." \
    || no "secrets/deploy_token debe ser 600 o 400 (ahora $mode)."
else
  no "Falta secrets/deploy_token con DEPLOY_TOKEN=..."
fi

if grep -RIn --exclude-dir=logs --exclude-dir=secrets --exclude=pipeline.yml "$TOKEN" "$P" >/dev/null 2>&1; then
  no "El token sigue escrito en jobs u otros ficheros del repo."
else
  ok "El token no está hardcodeado en jobs/."
fi

if (cd "$P" && su -s /bin/bash analista -c './run-ci.sh' >/tmp/ci87.out 2>&1); then
  ok "./run-ci.sh termina 0."
else
  no "./run-ci.sh falló:"; tail -n 20 /tmp/ci87.out
fi

if $SUDO grep -q "$TOKEN" "$P/logs/last-run.log" /tmp/ci87.out 2>/dev/null; then
  no "El log de CI todavía imprime el token."
else
  ok "El log nuevo no contiene el token."
fi

if [ -f "$P/dist/shop.txt" ] && [ -f "$P/dist/deployed.txt" ]; then
  ok "Hay artefacto y marca de deploy."
else
  no "Faltan dist/shop.txt o dist/deployed.txt."
fi
rm -f /tmp/ci87.out

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Pipeline sin fugas ni socket. ¡Lab 87 resuelto!"; exit 0; } || exit 1
