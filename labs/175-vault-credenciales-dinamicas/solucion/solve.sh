#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
export VAULT_ADDR=http://127.0.0.1:8200
VPASS=$(sed -n 's/^password=//p' ~/credenciales/postgres-vault.txt)

# 1. Rotar: tienda_app ya no entra (la app usará usuarios de Vault).
sudo -u postgres psql -q -c "ALTER ROLE tienda_app NOLOGIN PASSWORD NULL;"

# 2. Sacar el secreto del repo.
cd ~/api
git rm -q --cached .env && rm -f .env
echo ".env" >> .gitignore
git add .gitignore && git commit -qm "Quita .env del repo (secreto rotado; credenciales desde Vault)"
gitleaks dir --no-banner ~/api

# 3. Motor database y rol.
vault secrets enable database
vault write database/config/postgresql plugin_name=postgresql-database-plugin \
  allowed_roles=tienda \
  connection_url="postgresql://{{username}}:{{password}}@127.0.0.1:5432/tienda?sslmode=disable" \
  username=vault_admin password="$VPASS"
vault write -force database/rotate-root/postgresql     # ni nosotros sabemos ya la de vault_admin
vault write database/roles/tienda db_name=postgresql default_ttl=1h max_ttl=24h \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE tienda_rw;"
vault read database/creds/tienda

# 4. Política y token de la app.
vault policy write tienda - <<'HCL'
path "database/creds/tienda" {
  capabilities = ["read"]
}
HCL
vault token create -policy=tienda -period=24h -field=token | sudo tee /etc/tienda/vault-token >/dev/null
sudo chown root:analista /etc/tienda/vault-token && sudo chmod 0640 /etc/tienda/vault-token

# 5. La app pide credenciales al arrancar.
sudo tee /usr/local/bin/tienda-con-vault >/dev/null <<'SH'
#!/usr/bin/env bash
# Pide credenciales dinámicas a Vault y arranca la tienda con ellas.
set -euo pipefail
export VAULT_ADDR=http://127.0.0.1:8200
VAULT_TOKEN=$(cat /etc/tienda/vault-token) ; export VAULT_TOKEN
CREDS=$(vault read -format=json database/creds/tienda)
export DB_USER=$(jq -r .data.username <<<"$CREDS")
export DB_PASSWORD=$(jq -r .data.password <<<"$CREDS")
unset VAULT_TOKEN
exec /usr/bin/python3 /home/analista/api/app.py
SH
sudo chmod 0755 /usr/local/bin/tienda-con-vault
sudo sed -i 's#^EnvironmentFile=/etc/tienda/env#\# credenciales: Vault (tienda-con-vault)#; s#^ExecStart=.*#ExecStart=/usr/local/bin/tienda-con-vault#' \
  /etc/systemd/system/tienda.service
sudo rm -f /etc/tienda/env
sudo systemctl daemon-reload && sudo systemctl restart tienda
sleep 2
curl -s localhost:8080/; echo
echo "solve.sh completado."
