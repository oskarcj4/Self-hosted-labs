#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
APP=/opt/shop
V=$APP/migrations/versions

# EXPAND: añade nombre_completo y copia los datos. Las dos columnas conviven.
cat > "$V/0002_expand.py" <<'PY'
from alembic import op
import sqlalchemy as sa

revision = "0002"
down_revision = "0001"
branch_labels = None
depends_on = None

def upgrade():
    op.add_column("clientes", sa.Column("nombre_completo", sa.String(100)))
    op.execute("UPDATE clientes SET nombre_completo = nombre")

def downgrade():
    with op.batch_alter_table("clientes") as b:
        b.drop_column("nombre_completo")
PY

# CONTRACT: ya nadie usa 'nombre'; se elimina (batch para SQLite).
cat > "$V/0003_contract.py" <<'PY'
from alembic import op
import sqlalchemy as sa

revision = "0003"
down_revision = "0002"
branch_labels = None
depends_on = None

def upgrade():
    with op.batch_alter_table("clientes") as b:
        b.drop_column("nombre")

def downgrade():
    op.add_column("clientes", sa.Column("nombre", sa.String(100)))
    op.execute("UPDATE clientes SET nombre = nombre_completo")
PY

cd "$APP"
alembic upgrade head

# La app nueva usa la columna nueva.
cat > "$APP/app.py" <<'PY'
import sqlite3
db = sqlite3.connect("/opt/shop/db.sqlite")
for row in db.execute("SELECT id, nombre_completo FROM clientes"):
    print(row)
PY

echo "--- esquema final ---"
sqlite3 "$APP/db.sqlite" "PRAGMA table_info(clientes);"
echo "solve.sh completado."
