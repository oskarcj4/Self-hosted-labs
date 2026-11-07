#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/infra
M=modules/equipo
mkdir -p $M

cat > $M/versions.tf <<'TF'
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "2.35.1" }
  }
}
TF
cat > $M/variables.tf <<'TF'
variable "nombre" {
  type        = string
  description = "Nombre del equipo; también es el nombre del namespace."
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nombre))
    error_message = "nombre: sólo minúsculas, dígitos y guiones."
  }
}

variable "cpu" {
  type        = string
  description = "requests.cpu total del namespace."
}

variable "memoria" {
  type        = string
  description = "requests.memory total del namespace."
}

variable "pods" {
  type        = number
  description = "Número máximo de pods."
  default     = 30
}
TF
cat > $M/main.tf <<'TF'
resource "kubernetes_namespace_v1" "this" {
  metadata {
    name   = var.nombre
    labels = { equipo = var.nombre }
  }
}

resource "kubernetes_resource_quota_v1" "this" {
  metadata {
    name      = "cuota"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = var.cpu
      "requests.memory" = var.memoria
      pods              = tostring(var.pods)
    }
  }
}

resource "kubernetes_limit_range_v1" "this" {
  metadata {
    name      = "defaults"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
  }
  spec {
    limit {
      type            = "Container"
      default_request = { cpu = "50m", memory = "32Mi" }
      default         = { cpu = "500m", memory = "256Mi" }
    }
  }
}
TF
cat > $M/outputs.tf <<'TF'
output "namespace" {
  description = "Nombre del namespace del equipo."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
TF

cat > main.tf <<'TF'
locals {
  equipos = {
    pagos    = { cpu = "2", memoria = "4Gi" }
    catalogo = { cpu = "1", memoria = "2Gi" }
    envios   = { cpu = "1", memoria = "1Gi" }
    soporte  = { cpu = "1", memoria = "1Gi" }
  }
}

module "equipo" {
  source   = "./modules/equipo"
  for_each = local.equipos

  nombre  = each.key
  cpu     = each.value.cpu
  memoria = each.value.memoria
}

output "namespaces" {
  value = { for k, m in module.equipo : k => m.namespace }
}
TF

{
for e in pagos catalogo envios; do
  for r in namespace_v1 resource_quota_v1 limit_range_v1; do
    cat <<TF
moved {
  from = kubernetes_$r.$e
  to   = module.equipo["$e"].kubernetes_$r.this
}

TF
  done
done
} > moved.tf

terraform init -input=false >/dev/null
terraform validate
terraform plan -input=false -no-color | grep -E 'Plan:|has moved|destroy' || true
terraform apply -auto-approve -input=false
terraform plan -detailed-exitcode -input=false
echo "solve.sh completado."
