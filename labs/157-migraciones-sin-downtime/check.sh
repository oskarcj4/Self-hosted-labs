#!/usr/bin/env bash
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
APP=/opt/shop
DB=$APP/db.sqlite
cols(){ sqlite3 "$DB" "PRAGMA table_info(clientes);" 2>/dev/null | cut -d'|' -f2; }

echo "== Lab 157 · Migraciones sin downtime — comprobación =="

# 1) Alembic está en head (sin migraciones pendientes)
cd "$APP" 2>/dev/null
CUR=$(alembic current 2>/dev/null)
HEADS=$(alembic heads 2>/dev/null | awk '{print $1}')
if echo "$CUR" | grep -q "$(echo "$HEADS" | head -1)" && [ -n "$HEADS" ]; then
  ok "Alembic está aplicado hasta head."
else
  no "Hay migraciones sin aplicar (corre 'alembic upgrade head')."
fi

# 2) La columna nueva existe
if cols | grep -qx 'nombre_completo'; then
  ok "La columna 'nombre_completo' existe."
else
  no "Falta la columna 'nombre_completo' (fase expand)."
fi

# 3) La vieja ya no existe (fase contract)
if cols | grep -qx 'nombre'; then
  no "La columna 'nombre' sigue ahí (falta la fase contract)."
else
  ok "La columna 'nombre' fue eliminada (contract hecho)."
fi

# 4) Los datos se conservaron
N=$(sqlite3 "$DB" "SELECT count(*) FROM clientes WHERE nombre_completo LIKE '%Elliot%';" 2>/dev/null)
if [ "$N" = "1" ]; then
  ok "Los datos se copiaron a 'nombre_completo' (Elliot Alderson presente)."
else
  no "Los datos no se migraron a 'nombre_completo'."
fi

# 5) Hay al menos 3 revisiones (baseline + expand + contract)
R=$(ls "$APP"/migrations/versions/*.py 2>/dev/null | wc -l)
if [ "$R" -ge 3 ]; then
  ok "Historial con $R revisiones (baseline + expand + contract)."
else
  no "Se esperaban 3 revisiones; hay $R (crea expand y contract por separado)."
fi

# 6) La app usa la columna nueva
if grep -q 'nombre_completo' "$APP/app.py" 2>/dev/null && ! grep -qE 'SELECT[^_]*\bnombre\b' "$APP/app.py" 2>/dev/null; then
  ok "app.py usa 'nombre_completo'."
else
  no "Actualiza app.py para leer 'nombre_completo'."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Columna renombrada sin downtime (expand/contract)."; exit 0; } || exit 1
