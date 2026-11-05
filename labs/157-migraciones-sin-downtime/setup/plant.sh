#!/usr/bin/env bash
# Lab 157: hay que renombrar una columna de 'clientes' SIN downtime. El cambio
# ingenuo (renombrar de golpe) rompe la app durante el despliegue. El alumno
# aplica el patrón expand/contract con Alembic.
set -e
APP=/opt/shop
install -d -m 0755 "$APP/migrations/versions"

cat > "$APP/alembic.ini" <<'INI'
[alembic]
script_location = /opt/shop/migrations
sqlalchemy.url = sqlite:////opt/shop/db.sqlite
INI

cat > "$APP/migrations/env.py" <<'PY'
from alembic import context
from sqlalchemy import engine_from_config, pool

config = context.config
connectable = engine_from_config(
    config.get_section(config.config_ini_section),
    prefix="sqlalchemy.", poolclass=pool.NullPool,
)
with connectable.connect() as connection:
    context.configure(connection=connection, render_as_batch=True)
    with context.begin_transaction():
        context.run_migrations()
PY

cat > "$APP/migrations/script.py.mako" <<'MAKO'
"""${message}

Revision ID: ${up_revision}
Revises: ${down_revision | comma,n}
"""
from alembic import op
import sqlalchemy as sa

revision = ${repr(up_revision)}
down_revision = ${repr(down_revision)}
branch_labels = ${repr(branch_labels)}
depends_on = ${repr(depends_on)}

def upgrade():
    ${upgrades if upgrades else "pass"}

def downgrade():
    ${downgrades if downgrades else "pass"}
MAKO

# Migración base: tabla clientes con columna 'nombre' + datos sembrados.
cat > "$APP/migrations/versions/0001_baseline.py" <<'PY'
from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    op.create_table(
        "clientes",
        sa.Column("id", sa.Integer, primary_key=True),
        sa.Column("nombre", sa.String(100), nullable=False),
    )
    op.execute("INSERT INTO clientes (id, nombre) VALUES "
               "(1,'Elliot Alderson'),(2,'Angela Moss'),(3,'Tyrell Wellick')")

def downgrade():
    op.drop_table("clientes")
PY

# App que lee la columna 'nombre' (estado actual).
cat > "$APP/app.py" <<'PY'
import sqlite3
db = sqlite3.connect("/opt/shop/db.sqlite")
for row in db.execute("SELECT id, nombre FROM clientes"):
    print(row)
PY

cd "$APP"
alembic upgrade head >/dev/null 2>&1
chown -R analista:analista "$APP"

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Renombrar una columna SIN downtime (expand/contract)

En /opt/shop hay un proyecto Alembic (SQLite en /opt/shop/db.sqlite). La tabla
'clientes' tiene la columna 'nombre'. Negocio pide renombrarla a
'nombre_completo'. Renombrarla de golpe rompería la app vieja mientras se
despliega la nueva. Hazlo con el patrón expand/contract:

  EXPAND  (revisión 1): añade 'nombre_completo' (nullable), copia los datos
          desde 'nombre'. Ahora conviven las dos columnas: la app vieja sigue
          usando 'nombre', la nueva ya puede usar 'nombre_completo'.
  (despliegas la app nueva, que escribe/lee 'nombre_completo')
  CONTRACT(revisión 2): elimina 'nombre'. Ya nadie la usa.

Pasos sugeridos:
  cd /opt/shop
  alembic revision -m "expand: add nombre_completo"    # edita versions/*.py
  alembic revision -m "contract: drop nombre"
  # usa op.add_column / op.execute (UPDATE) y batch_alter_table para drop en SQLite
  alembic upgrade head
  # actualiza app.py para leer 'nombre_completo'

Estado final esperado: 'clientes' tiene 'nombre_completo' (con los datos) y ya
NO tiene 'nombre'; 3 revisiones en el historial; app.py usa 'nombre_completo'.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 157 plantado."
