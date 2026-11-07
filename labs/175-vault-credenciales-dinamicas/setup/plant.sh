#!/usr/bin/env bash
# Lab 175: la contraseña de la base de datos de la tienda está en un .env
# commiteado (gitleaks la encuentra) y es la misma desde hace años. El alumno
# la rota, quita el secreto del repo y hace que la app pida a Vault
# credenciales dinámicas de corta duración, con un token de mínimo privilegio.
set -e
H=/home/analista
R=$H/api
LEAKED="Tnd19-$(head -c 30 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 22)"

# --- PostgreSQL ---------------------------------------------------------------------
systemctl enable --now postgresql
for _ in $(seq 1 30); do runuser -u postgres -- pg_isready -q && break; sleep 1; done
VAULT_PG_PASS=$(head -c 18 /dev/urandom | base64 | tr -dc 'A-Za-z0-9')
runuser -u postgres -- psql -q -v ON_ERROR_STOP=1 <<SQL
CREATE DATABASE tienda;
CREATE ROLE tienda_rw NOLOGIN;
CREATE ROLE tienda_app LOGIN PASSWORD '$LEAKED' IN ROLE tienda_rw;
CREATE ROLE vault_admin LOGIN CREATEROLE PASSWORD '$VAULT_PG_PASS';
GRANT tienda_rw TO vault_admin WITH ADMIN OPTION;
\c tienda
CREATE TABLE productos (id serial PRIMARY KEY, nombre text, stock int);
INSERT INTO productos (nombre, stock) VALUES ('camiseta', 40), ('taza', 12), ('gorra', 7);
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO tienda_rw;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO tienda_rw;
SQL
install -d -m 0700 /root/credenciales
printf 'usuario=vault_admin\npassword=%s\n' "$VAULT_PG_PASS" > /root/credenciales/postgres-vault.txt
install -d -m 0750 -o analista /home/analista/credenciales
cp /root/credenciales/postgres-vault.txt $H/credenciales/
chown analista:analista $H/credenciales/postgres-vault.txt; chmod 0600 $H/credenciales/postgres-vault.txt

# --- Vault (modo dev: en memoria, sólo para el lab) ------------------------------------
cat > /etc/systemd/system/vault.service <<'U'
[Unit]
Description=Vault (modo dev)
After=network.target
[Service]
ExecStart=/usr/local/bin/vault server -dev -dev-root-token-id=root -dev-listen-address=127.0.0.1:8200
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now vault
export VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=root
for _ in $(seq 1 30); do vault status >/dev/null 2>&1 && break; sleep 1; done
printf 'export VAULT_ADDR=http://127.0.0.1:8200\n' > /etc/profile.d/vault.sh
echo root > $H/.vault-token; chown analista:analista $H/.vault-token; chmod 0600 $H/.vault-token

# --- La app ----------------------------------------------------------------------------
mkdir -p $R /etc/tienda
cat > $R/app.py <<'PY'
"""Tienda: /stock lee de PostgreSQL con las credenciales del entorno."""
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import psycopg2


def conectar():
    return psycopg2.connect(host="127.0.0.1", dbname="tienda", application_name="tienda",
                            user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
                            connect_timeout=3)


class H(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            with conectar() as c, c.cursor() as cur:
                cur.execute("SELECT current_user, sum(stock) FROM productos")
                usuario, stock = cur.fetchone()
            code, body = 200, f"stock={stock} usuario={usuario}"
        except Exception as e:
            code, body = 500, f"error: {e}"
        b = body.encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def log_message(self, *a):
        pass


ThreadingHTTPServer(("127.0.0.1", 8080), H).serve_forever()
PY
cat > $R/.env <<E
DB_USER=tienda_app
DB_PASSWORD=$LEAKED
E
cat > $R/README.md <<'MD'
# api de la tienda
Arranque: `sudo systemctl start tienda` (lee /etc/tienda/env).
MD
cp $R/.env /etc/tienda/env; chmod 0640 /etc/tienda/env; chgrp analista /etc/tienda/env
chown -R analista:analista $R
runuser -u analista -- git -C $R init -q -b main
runuser -u analista -- git -C $R config user.name "Analista"
runuser -u analista -- git -C $R config user.email analista@tienda.local
runuser -u analista -- git -C $R add -A
runuser -u analista -- git -C $R commit -qm "api de la tienda"
cat > /etc/systemd/system/tienda.service <<'U'
[Unit]
Description=Tienda
After=postgresql.service vault.service
[Service]
User=analista
EnvironmentFile=/etc/tienda/env
ExecStart=/usr/bin/python3 /home/analista/api/app.py
Restart=always
RestartSec=2
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now tienda
echo "$LEAKED" > /opt/lab/.leaked; chmod 0600 /opt/lab/.leaked

cat > $H/TAREA.txt <<'TXT'
TAREA · Secretos en Vault: credenciales dinámicas (~/api)

La tienda entra a PostgreSQL con tienda_app y una contraseña fija desde 2019,
que además está commiteada en ~/api/.env (pruébalo: gitleaks detect -s ~/api).

1. La contraseña filtrada ya no debe servir para entrar.
2. Saca el secreto del repo: .env fuera del árbol y en .gitignore (commit).
   gitleaks dir ~/api debe salir limpio.
3. En Vault (VAULT_ADDR=http://127.0.0.1:8200, token root en ~/.vault-token):
   - motor database con conexión a PostgreSQL usando vault_admin
     (credenciales en ~/credenciales/postgres-vault.txt);
   - rol "tienda": crea usuarios con LOGIN, miembros de tienda_rw,
     default_ttl 1h y max_ttl 24h.
4. Política "tienda" que SOLO permita leer database/creds/tienda, y un token
   con esa política (no root) en /etc/tienda/vault-token.
5. La tienda arranca pidiendo credenciales a Vault con ese token: en
   PostgreSQL se conecta con un usuario v-...  (curl localhost:8080/).

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 175 plantado."
