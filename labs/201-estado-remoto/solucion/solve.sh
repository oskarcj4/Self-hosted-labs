#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
. ~/.config/tfstate/credenciales            # TF_HTTP_USERNAME / TF_HTTP_PASSWORD
cd ~/infra

# 1. Backend remoto con bloqueo; sin credenciales en el código.
cat > backend.tf <<'TF'
terraform {
  backend "http" {
    address        = "http://127.0.0.1:8500/state/tienda"
    lock_address   = "http://127.0.0.1:8500/state/tienda"
    unlock_address = "http://127.0.0.1:8500/state/tienda"
    lock_method    = "LOCK"
    unlock_method  = "UNLOCK"
  }
}
TF

# 2. Migrar el estado local al backend (copia el estado; no recrea nada).
terraform init -input=false -migrate-state -force-copy
TF_VAR_db_password="Primavera2024!" terraform plan -input=false -detailed-exitcode

# 3. Estado fuera del repo y del disco.
cat > .gitignore <<'G'
# Estado y caché de Terraform: viven en el backend remoto, nunca en git.
*.tfstate
*.tfstate.*
.terraform/
# Variables con secretos.
*.tfvars
!ejemplo.tfvars
G
git rm -q --cached terraform.tfstate terraform.tfvars
rm -f terraform.tfstate terraform.tfstate.backup terraform.tfvars
echo '# db_password se pasa con TF_VAR_db_password (gestor de secretos / CI).' > ejemplo.tfvars

# 4. Rotar la contraseña (estuvo en git): la nueva, fuera del repo.
NUEVA=$(head -c 24 /dev/urandom | base64 | tr -d '/+=' | head -c 24)
install -m 0600 /dev/null ~/.config/tfstate/db.env
echo "export TF_VAR_db_password=$NUEVA" > ~/.config/tfstate/db.env
. ~/.config/tfstate/db.env
terraform apply -input=false -auto-approve
terraform plan -input=false -detailed-exitcode

git add -A
git commit -qm "infra: estado en backend remoto con bloqueo; fuera de git; contraseña rotada fuera del repo"
git status --short
echo "solve.sh completado."
