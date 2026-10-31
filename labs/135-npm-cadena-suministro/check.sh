#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 135.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
A=/srv/app
val(){ grep -E "^$1=" /home/analista/npm.txt 2>/dev/null | head -1 | cut -d= -f2- | tr -d ' \r'; }
AS(){ if [ "$(id -un)" = analista ]; then (cd $A && "$@"); else (cd $A && sudo -u analista "$@"); fi; }

echo "== Lab 135 · Cadena de suministro npm — comprobación =="
[ "$(val paquete_malicioso)" = color-utilz ] && ok "Typosquat identificado: color-utilz." || no "npm.txt: paquete_malicioso incorrecto."
[ "$(val script)" = postinstall ] && ok "Script de instalación identificado (postinstall)." || no "npm.txt: script incorrecto (mira npm view <paquete> scripts)."
[ "$(val legitimo)" = color-utils ] && ok "Paquete legítimo identificado." || no "npm.txt: legitimo incorrecto."

[ "$(AS npm config get ignore-scripts 2>/dev/null)" = true ] && ok "npm no ejecuta scripts de instalación en el proyecto (ignore-scripts=true)." \
  || no "En /srv/app, 'npm config get ignore-scripts' no da true."
jq -e '.dependencies["color-utils"] and (.dependencies["color-utilz"] | not)' $A/package.json >/dev/null 2>&1 \
  && ok "package.json depende de color-utils (no del typosquat)." || no "package.json sigue sin la dependencia correcta."
if [ -f $A/package-lock.json ] && jq -e '.packages["node_modules/color-utils"].integrity and (.packages["node_modules/color-utilz"] | not)' $A/package-lock.json >/dev/null 2>&1; then
  ok "package-lock.json fija color-utils con su hash de integridad."
else
  no "Falta package-lock.json correcto (con color-utils y sin color-utilz)."
fi
[ -d $A/node_modules/color-utils ] && [ ! -e $A/node_modules/color-utilz ] && ok "node_modules: sólo dependencias legítimas." || no "node_modules no está instalado limpio (¿npm ci?)."
AS node index.js >/dev/null 2>&1 && ok "La aplicación arranca con las dependencias instaladas." || no "node index.js falla."
[ -e /tmp/.color-cache ] && no "Quedan restos del postinstall malicioso en /tmp/.color-cache (y habría que rotar el token de npm)." \
  || ok "No hay restos del postinstall malicioso."

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Dependencias revisadas e instalación endurecida."; exit 0; } || exit 1
