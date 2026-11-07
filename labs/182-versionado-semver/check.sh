#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
R=/home/analista/tienda-sdk
SV=$R/scripts/siguiente-version
g(){ git -C $R "$@"; }

echo "== Lab 182 · Versionado semántico — comprobación =="

if [ -x "$SV" ]; then
  OUT=$(cd /tmp && timeout 120 runuser -u analista -- bash /opt/lab/tests/casos.sh "$SV" 2>&1); rc=$?
  echo "$OUT" | sed 's/^/      /'
  [ $rc = 0 ] && ok "scripts/siguiente-version supera los casos ocultos." || no "scripts/siguiente-version falla casos ocultos (arriba)."
else
  no "Falta ~/tienda-sdk/scripts/siguiente-version (ejecutable)."
fi

V=$(cat $R/VERSION 2>/dev/null)
if [ "$V" = 2.0.0 ] && [ "$(g cat-file -t v2.0.0 2>/dev/null)" = tag ] && [ "$(g show v2.0.0:VERSION 2>/dev/null)" = 2.0.0 ] \
   && g log -1 --format=%s 'v2.0.0^{commit}' | grep -qx 'chore(release): 2.0.0'; then
  ok "Release 2.0.0: VERSION, commit chore(release) y etiqueta anotada v2.0.0."
elif [ "$V" = 1.5.0 ] || g rev-parse -q --verify v1.5.0 >/dev/null; then
  no "1.5.0 no es correcta: algún commit desde v1.4.2 rompe la compatibilidad (lee los cuerpos)."
else
  no "Falta la release: VERSION=$V; se espera commit 'chore(release): X.Y.Z' y etiqueta anotada vX.Y.Z."
fi

SEC=$(sed -n '/^## \[/{p;:a;n;/^## \[/q;p;ba}' $R/CHANGELOG.md 2>/dev/null)
if echo "$SEC" | head -1 | grep -qE '^## \[2\.0\.0\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' \
   && echo "$SEC" | grep -q '^### Cambios incompatibles' && echo "$SEC" | grep -qi 'decimal' \
   && echo "$SEC" | grep -q '^### Nuevas funciones' && echo "$SEC" | grep -qi 'carrito' \
   && echo "$SEC" | grep -q '^### Correcciones' && grep -q '^## \[1\.4\.2\]' $R/CHANGELOG.md; then
  ok "CHANGELOG: sección 2.0.0 arriba con incompatibles (Decimal), funciones (carrito) y correcciones."
else
  no "CHANGELOG.md: '## [2.0.0] - AAAA-MM-DD' arriba, con las tres subsecciones y su contenido."
fi

T=$(mktemp -d); git clone -q $R $T/c 2>/dev/null
if [ -x "$SV" ] && git -C $T/c rev-parse -q --verify 'v2.0.0^{commit}' >/dev/null; then
  git -C $T/c reset -q --hard 'v2.0.0^{commit}~1'; git -C $T/c tag -d v2.0.0 >/dev/null
  chown -R analista $T
  P=$(cd $T/c && runuser -u analista -- "$SV" 2>/dev/null)
  [ "$P" = 2.0.0 ] && ok "Tu script, justo antes de la release, también dice 2.0.0." \
                   || no "Tu script, justo antes de la release, dice '$P' (esperado 2.0.0)."
else
  no "No se puede comprobar el script sobre el historial real (falta la etiqueta v2.0.0)."
fi
rm -rf $T

if [ -z "$(g status --porcelain)" ]; then ok "Árbol limpio."; else no "Hay cambios sin commit en ~/tienda-sdk."; fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Versiones que dicen la verdad sobre los cambios."; exit 0; } || exit 1
