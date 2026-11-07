#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 160.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
M=${MONOREPO:-/home/analista/monorepo}
T=$(mktemp -d)
G(){ git -C "$T" -c user.name=check -c user.email=check@lab "$@"; }
commit(){ G add -A >/dev/null && G commit -qm "$1" >/dev/null; G rev-parse HEAD; }
changed(){ (cd "$T" && bash ci/changed.sh "$1" "$2" 2>/dev/null) | sed '/^\s*$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'; }

echo "== Lab 160 · Monorepo — comprobación =="

if [ -n "$(git -C "$M" status --porcelain 2>/dev/null)" ]; then
  no "Hay cambios sin commit en ~/monorepo (haz commit)."
fi
if [ ! -f "$M/ci/changed.sh" ]; then
  no "Falta ~/monorepo/ci/changed.sh."
  echo "Resultado: $pass superados, $((fail)) pendientes."; exit 1
fi
git clone -q "$M" "$T"
B0=$(G rev-parse HEAD)

echo "x = 1" >> "$T/services/pagos/app.py";            C1=$(commit "pagos")
echo "# y" >> "$T/libs/comun/util.py";                 C2=$(commit "comun")
echo "nota" >> "$T/docs/arquitectura.md"; echo "-" >> "$T/README.md"; C3=$(commit "docs")
echo "x = 2" >> "$T/services/catalogo/app.py"; echo "x = 3" >> "$T/services/notificaciones/app.py"; C4=$(commit "dos")
mkdir -p "$T/services/envios"; echo 'print("envios")' > "$T/services/envios/app.py"; : > "$T/services/envios/deps.txt"; C5=$(commit "nuevo")

t(){ # t <descripción> <base> <head> <esperado>
  local got; got=$(changed "$2" "$3")
  if [ "$got" = "$4" ]; then ok "$1 → '${4:-(nada)}'"; else no "$1: se esperaba '${4:-(nada)}', ci/changed.sh dio '${got:-(nada)}'"; fi
}
t "Cambio sólo en services/pagos"          "$B0" "$C1" "pagos"
t "Cambio en libs/comun (dependencia)"     "$C1" "$C2" "catalogo pagos"
t "Sólo docs/ y README.md"                 "$C2" "$C3" ""
t "Dos servicios en un commit"             "$C3" "$C4" "catalogo notificaciones"
t "Servicio nuevo services/envios"         "$C4" "$C5" "envios"
t "Rango de varios commits (unión)"        "$B0" "$C3" "catalogo pagos"

# El pipeline construye sólo lo afectado
run_pipe(){ rm -rf "$T/.art"; (cd "$T" && git checkout -q "$2" && ARTEFACTOS="$T/.art" CI_BASE="$1" CI_HEAD="$2" \
  bash ci/pipeline.sh >/dev/null 2>&1); local rc=$?; ls "$T/.art" 2>/dev/null | sort | tr '\n' ' ' | sed 's/ $//'; return $rc; }
P1=$(run_pipe "$B0" "$C1"); r1=$?
P3=$(run_pipe "$C2" "$C3"); r3=$?
if [ $r1 = 0 ] && [ "$P1" = "pagos" ] && [ $r3 = 0 ] && [ -z "$P3" ]; then
  ok "ci/pipeline.sh construye sólo lo afectado (y nada si sólo cambian docs)."
else
  no "ci/pipeline.sh debe construir sólo lo de ci/changed.sh: pagos→'${P1}' (rc $r1), docs→'${P3}' (rc $r3)."
fi
rm -rf "$T"

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 El CI construye sólo lo que cambió."; exit 0; } || exit 1
