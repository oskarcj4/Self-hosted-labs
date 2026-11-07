# Solución — Estado remoto de Terraform

```hcl
# ~/infra/backend.tf
terraform {
  backend "http" {
    address        = "http://127.0.0.1:8500/state/tienda"
    lock_address   = "http://127.0.0.1:8500/state/tienda"
    unlock_address = "http://127.0.0.1:8500/state/tienda"
  }
}
```

```bash
source ~/.config/tfstate/credenciales          # TF_HTTP_USERNAME / TF_HTTP_PASSWORD
cd ~/infra
terraform init -migrate-state                  # copia el estado local al backend
terraform plan -detailed-exitcode              # 0: nada que cambiar

printf '*.tfstate\n*.tfstate.*\n.terraform/\n*.tfvars\n' > .gitignore
git rm --cached terraform.tfstate terraform.tfvars
rm -f terraform.tfstate terraform.tfstate.backup terraform.tfvars

export TF_VAR_db_password=$(openssl rand -base64 18)   # en un gestor de secretos, no en el repo
terraform apply
git add -A && git commit -m "infra: estado remoto, fuera de git, contraseña rotada"
```

El script completo está en `solve.sh`.

## Antes y después

| | Estado en git | Backend remoto |
|---|---|---|
| Copias | una por clon, divergentes | una |
| Dos `apply` a la vez | se pisan | el segundo espera (`Error acquiring the state lock`) |
| Secretos | en el historial para siempre | en un servidor con acceso controlado |
| Historial | commits mezclados con código | versiones del backend |

## Relación con otros labs

- Lab 168: qué hacer con un bloqueo huérfano (`terraform force-unlock`), drift e `import`.
- Lab 175: Vault, para no tener contraseñas de larga duración que rotar.
