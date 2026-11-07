#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
H=/home/analista; I=$H/infra
. /opt/lab/.credenciales
VIEJA=$(cat /opt/lab/.clave-vieja)
U="$TF_HTTP_USERNAME:$TF_HTTP_PASSWORD"
AN(){ runuser -u analista -- env HOME=$H TF_HTTP_USERNAME=$TF_HTTP_USERNAME TF_HTTP_PASSWORD=$TF_HTTP_PASSWORD "$@"; }

echo "== Lab 201 · Estado remoto de Terraform — comprobación =="

# 1) Backend en el código, con bloqueo y sin credenciales
TFS=$(cat $I/*.tf 2>/dev/null)
if echo "$TFS" | grep -q 'backend *"http"' && echo "$TFS" | grep -q '127.0.0.1:8500/state/tienda' \
   && echo "$TFS" | grep -q 'lock_address' && echo "$TFS" | grep -q 'unlock_address'; then
  ok "backend \"http\" apuntando a /state/tienda, con lock_address y unlock_address."
else
  no "Falta en ~/infra/*.tf un backend \"http\" a http://127.0.0.1:8500/state/tienda con lock_address y unlock_address."
fi
if echo "$TFS" | grep -qE '^\s*(username|password)\s*=' || grep -rqs "$TF_HTTP_PASSWORD" $I --include='*.tf' --include='*.hcl'; then
  no "Hay credenciales del backend escritas en el código (usa TF_HTTP_USERNAME/TF_HTTP_PASSWORD)."
else
  ok "Las credenciales del backend no están en el código."
fi

# 2) Estado en el servidor, con los tres recursos
EST=$(curl -s -u "$U" http://127.0.0.1:8500/state/tienda)
NR=$(echo "$EST" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print(0); sys.exit()
print(sum(1 for r in d.get("resources",[]) if r.get("mode")=="managed"))' 2>/dev/null)
[ "${NR:-0}" -ge 3 ] && ok "El estado vive en el servidor remoto ($NR recursos)." \
                     || no "El servidor remoto no tiene el estado 'tienda' con los 3 recursos (tiene ${NR:-0})."

# 3) Fuera de git y del disco
TRK=$(runuser -u analista -- git -C $I ls-files | grep -E '\.tfstate' | tr '\n' ' ')
LOC=$(ls $I/terraform.tfstate* 2>/dev/null | tr '\n' ' ')
GI=$(cat $I/.gitignore 2>/dev/null)
SUC=$(runuser -u analista -- git -C $I status --porcelain 2>/dev/null | grep -v '^??' | head -3)
if [ -z "$TRK" ] && [ -z "$LOC" ] && echo "$GI" | grep -qF '*.tfstate' && echo "$GI" | grep -qF '*.tfstate.*' \
   && echo "$GI" | grep -qF '.terraform' && [ -z "$SUC" ]; then
  ok "Ni git ni ~/infra guardan estado, .gitignore lo impide y todo está commiteado."
else
  no "Estado fuera del repo: en git='${TRK:-no}', en disco='${LOC:-no}', .gitignore incompleto o cambios sin commit ($SUC)."
fi

# 4) Contraseña rotada, fuera del repo
NUEVA=$(echo "$EST" | python3 -c '
import json,sys,re
try: d=json.load(sys.stdin)
except Exception: sys.exit()
for r in d.get("resources",[]):
    if r.get("type")=="local_sensitive_file":
        for i in r.get("instances",[]):
            m=re.search(r"DB_PASSWORD=(.*)", i["attributes"].get("content",""))
            if m: print(m.group(1))' 2>/dev/null)
DISCO=$(sed -n 's/^DB_PASSWORD=//p' /srv/tienda/db.env 2>/dev/null)
ENGIT=""
if [ -n "$NUEVA" ]; then
  ENGIT=$(runuser -u analista -- git -C $I grep -I -l -F -e "$NUEVA" HEAD -- . 2>/dev/null | head -1)
fi
VIEJAGIT=$(runuser -u analista -- git -C $I grep -I -l -F -e "$VIEJA" HEAD -- . 2>/dev/null | head -1)
if [ -n "$NUEVA" ] && [ "$NUEVA" != "$VIEJA" ] && [ "$DISCO" = "$NUEVA" ] && [ -z "$ENGIT" ] && [ -z "$VIEJAGIT" ]; then
  ok "Contraseña rotada y aplicada (/srv/tienda/db.env); la nueva no está en el repo."
else
  no "Contraseña: hay que rotarla (sigue la vieja o no se aplicó), sin dejar ni la vieja ni la nueva en ficheros del repo."
fi

# 5) Un compañero: clon limpio, init, plan sin cambios y respeto del bloqueo
T=$(mktemp -d); chown analista:analista $T
if AN git clone -q $I $T/w 2>/dev/null && AN terraform -chdir=$T/w init -input=false >/dev/null 2>&1; then
  AN env TF_VAR_db_password="$NUEVA" terraform -chdir=$T/w plan -input=false -detailed-exitcode >$T/plan 2>&1; P=$?
  [ $P -eq 0 ] && ok "Clon limpio + init + plan: sin cambios (el compañero ve el mismo estado)." \
               || no "En un clon limpio, terraform plan propone cambios o falla (código $P): $(grep -E 'Error|will be|must be' $T/plan | head -1)"
  curl -s -u "$U" -X LOCK -d '{"ID":"check-201","Operation":"OperationTypeApply","Who":"companero@ci"}' \
       http://127.0.0.1:8500/state/tienda >/dev/null
  AN env TF_VAR_db_password="$NUEVA" terraform -chdir=$T/w plan -input=false -lock-timeout=2s >$T/lock 2>&1; L=$?
  curl -s -u "$U" -X UNLOCK -d '{"ID":"check-201"}' http://127.0.0.1:8500/state/tienda >/dev/null
  [ $L -ne 0 ] && grep -q 'state lock' $T/lock \
    && ok "Con el estado bloqueado por otro, terraform espera y se niega a seguir." \
    || no "Con el estado bloqueado por otro, terraform siguió adelante: el backend no usa el bloqueo."
else
  no "Un clon limpio del repo no consigue hacer terraform init contra el backend."
  no "(no se puede probar el bloqueo)"
fi
rm -rf $T

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Un estado, compartido, bloqueado y fuera del repo."; exit 0; } || exit 1
