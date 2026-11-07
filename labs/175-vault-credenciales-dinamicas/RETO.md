# Secretos en Vault: credenciales dinámicas

> DevSecOps · Vault · database secrets engine · políticas · rotación · gitleaks

## Escenario

La tienda entra en PostgreSQL como `tienda_app`, con la misma contraseña
desde 2019. Esa contraseña está **commiteada** en `~/api/.env`:

```bash
gitleaks detect -s ~/api
```

Con un secreto fijo y filtrado, cualquiera con una copia del repo (o de un
backup, o de un portátil robado) entra en la base de datos, y no hay forma de
saber quién fue.

**Vault** con el motor `database` crea un usuario de PostgreSQL **distinto en
cada petición**, con caducidad (TTL), y lo borra al caducar. La app sólo
guarda un token de Vault con permiso para pedir credenciales.

Vault corre en modo dev en `http://127.0.0.1:8200` (token `root` en
`~/.vault-token`). Las credenciales de `vault_admin` (rol de PostgreSQL con
CREATEROLE) están en `~/credenciales/postgres-vault.txt`.

## Objetivos

1. La contraseña filtrada ya no sirve para entrar.
2. `.env` fuera del repo y en `.gitignore` (commit); `gitleaks dir ~/api` limpio.
3. Motor `database` con el rol `tienda`: usuarios con LOGIN, miembros de
   `tienda_rw`, `default_ttl=1h`, `max_ttl=24h`.
4. Política `tienda` que **sólo** lee `database/creds/tienda`; un token con
   ella (no root) en `/etc/tienda/vault-token`.
5. La tienda arranca con credenciales de Vault (usuario `v-...`).

## Pistas

```bash
vault secrets enable database
vault write database/config/postgresql plugin_name=postgresql-database-plugin \
  allowed_roles=tienda connection_url="postgresql://{{username}}:{{password}}@127.0.0.1:5432/tienda?sslmode=disable" \
  username=vault_admin password=...
vault write database/roles/tienda db_name=postgresql default_ttl=1h max_ttl=24h \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE tienda_rw;"
vault read database/creds/tienda
vault policy write tienda politica.hcl
vault token create -policy=tienda
vault token capabilities <token> database/creds/tienda
sudo -u postgres psql -c "ALTER ROLE tienda_app NOLOGIN"
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
