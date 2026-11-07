#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
T=/opt/tienda
DB=/var/lib/tienda/tienda.db
U=http://127.0.0.1:8080

echo "== Lab 191 · Rollback con cambio de base de datos — comprobación =="

if (cd $T/releases/v1 && md5sum --quiet -c /opt/lab/tests/v1.md5 >/dev/null 2>&1) \
   && [ "$(cd $T/releases/v1 && find . -type f | wc -l)" = "$(wc -l < /opt/lab/tests/v1.md5)" ]; then
  ok "La v1 (en producción) no se ha tocado."
else
  no "La v1 ha cambiado: está en producción y el rollback va a esa v1, tal cual."
fi
if grep -qiE '\b(rename|drop)\b' $T/releases/v2/migraciones/*.sql; then
  no "Las migraciones de v2 siguen con RENAME o DROP: eso es la fase de contraer, no de esta release."
else
  ok "Las migraciones de v2 sólo añaden (expandir)."
fi

# Prueba de ida y vuelta, en una copia de la base de datos de producción.
cp -p $DB /tmp/c191.db.bak
ANTES=$(python3 -c "import sqlite3;print(sqlite3.connect('$DB').execute('select count(*) from clientes').fetchone()[0])")
nombres(){ curl -s --max-time 3 $U/clientes | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("ERROR"); sys.exit()
print("ERROR" if not isinstance(d,list) else "\n".join(str(x.get("nombre")) for x in d))'; }
alta(){ curl -s -o /dev/null -w '%{http_code}' -X POST "$U/clientes?nombre=$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$1")"; }
ver(){ curl -s --max-time 3 $U/version | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])' 2>/dev/null; }

desplegar v2 >/tmp/c191.log 2>&1; V=$(ver)
N2=$(nombres); A2=$(alta "Nuria Nueva (v2)")
if [ "$V" = v2 ] && [ "$N2" != ERROR ] && [ "$(echo "$N2" | grep -c .)" = "$ANTES" ] && [ "$A2" = 201 ] && ! echo "$N2" | grep -qx None; then
  ok "desplegar v2: responde, con los $ANTES clientes con nombre, y da de alta."
else
  no "desplegar v2: versión '${V:-?}', listado $( [ "$N2" = ERROR ] && echo 'con error' || echo "de $(echo "$N2" | grep -c .) clientes"), alta HTTP $A2 ($(tail -1 /tmp/c191.log))."
fi

desplegar v1 >/tmp/c191.log 2>&1; V=$(ver)
N1=$(nombres); A1=$(alta "Raúl Rollback (v1)")
if [ "$V" = v1 ] && [ "$N1" != ERROR ] && [ "$A1" = 201 ]; then
  ok "Rollback a v1: la tienda funciona (listar y dar de alta)."
else
  no "Rollback a v1: versión '${V:-?}', listado $( [ "$N1" = ERROR ] && echo 'en error 500' || echo bien), alta HTTP $A1."
fi
if echo "$N1" | grep -qx 'Nuria Nueva (v2)' && ! echo "$N1" | grep -qx None; then
  ok "Lo que se creó con v2 se ve, con su nombre, tras el rollback."
else
  no "Tras el rollback, el cliente creado en v2 no aparece o no tiene nombre."
fi

desplegar v2 >/tmp/c191.log 2>&1; V=$(ver)
N3=$(nombres)
if [ "$V" = v2 ] && echo "$N3" | grep -qx 'Raúl Rollback (v1)' && echo "$N3" | grep -qx 'Nuria Nueva (v2)' && ! echo "$N3" | grep -qx None \
   && [ "$(echo "$N3" | grep -c .)" = $((ANTES+2)) ]; then
  ok "Volver a v2: están todos ($((ANTES+2))) y con nombre, también el creado por v1 tras el rollback."
else
  no "Volver a v2: faltan clientes o alguno sale sin nombre (None): $(echo "$N3" | tr '\n' ',' | cut -c1-120)."
fi

COLS=$(python3 -c "import sqlite3;print(' '.join(r[1] for r in sqlite3.connect('$DB').execute('pragma table_info(clientes)')))")
if echo " $COLS " | grep -q ' nombre_completo ' && grep -q 'nombre_completo' $T/releases/v2/app.py; then
  ok "v2 usa la columna nueva nombre_completo (columnas: $COLS)."
else
  no "v2 tiene que leer y escribir nombre_completo (columnas: $COLS)."
fi

# Deja producción como estaba: v1 y la base de datos original.
desplegar v1 >/dev/null 2>&1
systemctl stop tienda; cp -p /tmp/c191.db.bak $DB; systemctl start tienda

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Rollback de código posible en cualquier momento: expandir ahora, contraer después."; exit 0; } || exit 1
