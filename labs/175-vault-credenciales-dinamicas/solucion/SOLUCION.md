# Solución — Vault: credenciales dinámicas

```bash
export VAULT_ADDR=http://127.0.0.1:8200

# 1. Rotar
sudo -u postgres psql -c "ALTER ROLE tienda_app NOLOGIN PASSWORD NULL"

# 2. Repo
cd ~/api && git rm --cached .env && rm .env && echo .env >> .gitignore
git add .gitignore && git commit -m "Quita .env del repo"

# 3. Motor database
vault secrets enable database
vault write database/config/postgresql plugin_name=postgresql-database-plugin \
  allowed_roles=tienda \
  connection_url="postgresql://{{username}}:{{password}}@127.0.0.1:5432/tienda?sslmode=disable" \
  username=vault_admin password="<de ~/credenciales>"
vault write -force database/rotate-root/postgresql
vault write database/roles/tienda db_name=postgresql default_ttl=1h max_ttl=24h \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE tienda_rw;"

# 4. Política + token
vault policy write tienda - <<'HCL'
path "database/creds/tienda" { capabilities = ["read"] }
HCL
vault token create -policy=tienda -period=24h -field=token | sudo tee /etc/tienda/vault-token
```

`/usr/local/bin/tienda-con-vault` (nuevo `ExecStart` de `tienda.service`):
```bash
#!/usr/bin/env bash
set -euo pipefail
export VAULT_ADDR=http://127.0.0.1:8200
VAULT_TOKEN=$(cat /etc/tienda/vault-token); export VAULT_TOKEN
CREDS=$(vault read -format=json database/creds/tienda)
export DB_USER=$(jq -r .data.username <<<"$CREDS")
export DB_PASSWORD=$(jq -r .data.password <<<"$CREDS")
unset VAULT_TOKEN
exec /usr/bin/python3 /home/analista/api/app.py
```

## Por qué

| Antes | Después |
|-------|---------|
| Una contraseña fija, en git, compartida | Un usuario por arranque, que caduca |
| Rotar = cambiar config en todos lados | Vault rota; `rotate-root` cambia hasta la del admin |
| No se sabe quién usó la credencial | Cada lease tiene su usuario y se revoca sola |

## Más allá del lab

- Vault Agent o el CSI driver en Kubernetes renuevan las credenciales sin reiniciar la app.
- Con `max_ttl=24h` la app debe reiniciarse (o renovar) al menos una vez al día: pruébalo.
- Limpia el historial de git (`git filter-repo`) sólo después de rotar.
