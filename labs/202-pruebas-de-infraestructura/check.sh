#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista; I=$H/infra
T=$(mktemp -d); chown analista:analista $T
AN(){ runuser -u analista -- env HOME=$H TF_IN_AUTOMATION=1 "$@"; }
# copia <destino>: copia limpia de ~/infra (sin .terraform)
copia(){ AN mkdir -p "$1"; AN cp -r $I/. "$1/"; AN rm -rf "$1/modules/servicio/.terraform" "$1/.terraform";
         AN terraform -chdir="$1/modules/servicio" init -input=false >/dev/null 2>&1; }

echo "== Lab 202 · Pruebas de infraestructura — comprobación =="

copia $T/base
NT=$(cat $T/base/modules/servicio/tests/*.tftest.hcl 2>/dev/null | grep -cE '^\s*run\s+"')
if [ "${NT:-0}" -ge 4 ]; then
  ok "Hay $NT pruebas (run) en modules/servicio/tests/."
else
  no "Hay ${NT:-0} bloques run en modules/servicio/tests/*.tftest.hcl (al menos 4)."
fi

AN terraform -chdir=$T/base/modules/servicio test -no-color >$T/t 2>&1; R=$?
[ $R -eq 0 ] && [ "${NT:-0}" -ge 1 ] && ok "terraform test pasa con el módulo actual ($(grep -oE '[0-9]+ passed' $T/t | tail -1))." \
             || no "terraform test falla con el módulo actual: $(grep -E 'Error|fail' $T/t | head -2 | tr '\n' ' ')"

# Especificación oculta: el bug arreglado y el contrato intacto
copia $T/esp
AN rm -f $T/esp/modules/servicio/tests/*.tftest.hcl 2>/dev/null
AN mkdir -p $T/esp/modules/servicio/tests
cp /opt/lab/tests/oculto.tftest.hcl $T/esp/modules/servicio/tests/; chown -R analista:analista $T/esp
AN terraform -chdir=$T/esp/modules/servicio test -no-color >$T/o 2>&1 \
  && ok "El módulo cumple la especificación (upstream en puerto+i, validaciones)." \
  || no "El módulo no cumple la especificación: $(grep -E 'Error:|error_message|condition' $T/o | head -2 | tr '\n' ' ')"

# Mutantes
VIVOS=""; NOAPL=""
N=$(python3 -c 'import sys; sys.path.insert(0,"/opt/lab/tests"); import mutantes; print(len(mutantes.MUTANTES))')
for k in $(seq 0 $((N-1))); do
  D=$T/m$k; AN cp -r $T/base $D
  DESC=$(python3 - "$D/modules/servicio" "$k" <<'PY'
import sys, os
sys.path.insert(0, "/opt/lab/tests")
from mutantes import MUTANTES
d, k = sys.argv[1], int(sys.argv[2])
desc, f, viejo, nuevo = MUTANTES[k]
p = os.path.join(d, f)
s = open(p, encoding="utf-8").read()
if viejo not in s:
    print("NOAPLICA|" + desc); sys.exit()
open(p, "w", encoding="utf-8").write(s.replace(viejo, nuevo))
print("OK|" + desc)
PY
)
  case "$DESC" in
    NOAPLICA*) NOAPL="$NOAPL [${DESC#NOAPLICA|}]"; continue;;
  esac
  if AN terraform -chdir=$D/modules/servicio test >/dev/null 2>&1; then VIVOS="$VIVOS [${DESC#OK|}]"; fi
done
if [ -n "$NOAPL" ]; then
  no "No se pudieron aplicar mutantes (¿has reestructurado el módulo?):$NOAPL"
elif [ -z "$VIVOS" ]; then
  ok "Tus pruebas detectan los $N mutantes."
else
  no "Mutantes que tus pruebas NO detectan:$VIVOS"
fi

# ci/test.sh: verde con el módulo bueno, rojo con un mutante y con mal formato
if [ -x $I/ci/test.sh ] || [ -f $I/ci/test.sh ]; then
  (cd $T/base && AN bash ci/test.sh >/dev/null 2>&1); G=$?
  (cd $T/m2 && AN bash ci/test.sh >/dev/null 2>&1); B=$?
  AN cp -r $T/base $T/fmt; echo 'locals {   mal = 1 }' >> $T/fmt/modules/servicio/main.tf
  (cd $T/fmt && AN bash ci/test.sh >/dev/null 2>&1); F=$?
  [ $G -eq 0 ] && [ $B -ne 0 ] && [ $F -ne 0 ] \
    && ok "ci/test.sh: verde con el módulo bueno, rojo con un mutante y con formato incorrecto." \
    || no "ci/test.sh: bueno=$G (esperaba 0), mutante=$B y mal formato=$F (esperaba ≠0)."
else
  no "Falta ~/infra/ci/test.sh."
fi

SUC=$(AN git -C $I status --porcelain 2>/dev/null | grep -v '\.terraform' | head -3)
[ -z "$SUC" ] && AN git -C $I ls-files | grep -q 'tests/.*\.tftest\.hcl' \
  && ok "Pruebas y arreglo commiteados en ~/infra." \
  || no "Falta hacer commit en ~/infra (pendiente: $(echo $SUC))."
rm -rf $T

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Infra con pruebas que de verdad detectan los fallos."; exit 0; } || exit 1
