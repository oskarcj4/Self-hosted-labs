# Resolución guiada · Lab 175

:::piensa Borrar el .env no basta
El secreto está en el historial de git, y quién sabe en cuántos clones. Un
secreto filtrado se **rota** (deja de valer); quitarlo del repo sólo evita
filtrarlo otra vez.
:::

## Paso 1 · Rotar

:::pista Cómo hacerlo
Como la app pasará a usar usuarios de Vault, `tienda_app` ya no hace falta:
```bash
sudo -u postgres psql -c "ALTER ROLE tienda_app NOLOGIN PASSWORD NULL"
```
:::

## Paso 2 · Fuera del repo

:::pista Cómo hacerlo
```bash
cd ~/api && git rm --cached .env && rm .env && echo .env >> .gitignore
git add .gitignore && git commit -m "Quita .env"
gitleaks dir ~/api
```
:::

## Paso 3 · El motor database

:::pista Qué falta en el rol
`creation_statements` debe crear el rol con `LOGIN`, `PASSWORD '{{password}}'`,
`VALID UNTIL '{{expiration}}'` e `IN ROLE tienda_rw` (los permisos están en ese
grupo). Tras configurar la conexión, `vault write -force database/rotate-root/postgresql`
cambia la contraseña de `vault_admin` y sólo la conoce Vault.
:::

## Paso 4 · Mínimo privilegio

:::pista La política
```hcl
path "database/creds/tienda" {
  capabilities = ["read"]
}
```
`vault token create -policy=tienda -period=24h -field=token | sudo tee /etc/tienda/vault-token`
:::

## Paso 5 · La app

:::pista Cómo hacerlo
Un script de arranque que lee el token, pide `database/creds/tienda`, exporta
`DB_USER`/`DB_PASSWORD` y hace `exec python3 app.py`. Ponlo en el `ExecStart`
de `tienda.service` y quita el `EnvironmentFile`.
:::

## Cómo actuar en una situación así

- Secreto filtrado: rota primero, limpia después, y revisa los accesos con esas credenciales.
- Credenciales dinámicas: cada instancia tiene su usuario, así se ve quién hizo qué y se puede revocar uno solo.
- En producción, la app se autentica con AppRole o con su identidad de Kubernetes, no con un token en un fichero.

## Si te atascas

- "permission denied to grant role": `vault_admin` necesita `ADMIN OPTION` sobre `tienda_rw` (ya la tiene).
- `vault read database/creds/tienda` falla: `vault read database/config/postgresql` y revisa `allowed_roles`.
