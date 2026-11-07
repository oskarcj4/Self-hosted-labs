# Solución — Terraform: módulos reutilizables

## Estructura final

```
infra/
├── versions.tf          # provider kubernetes (sin cambios)
├── main.tf              # locals.equipos + module "equipo" (for_each) + output namespaces
├── moved.tf             # 9 bloques moved (3 equipos x 3 recursos)
└── modules/equipo/
    ├── versions.tf      # required_providers
    ├── variables.tf     # nombre (validation), cpu, memoria, pods = 30
    ├── main.tf          # namespace, ResourceQuota "cuota", LimitRange "defaults"
    └── outputs.tf       # output "namespace"
```

## Puntos clave

```hcl
variable "nombre" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nombre))
    error_message = "nombre: sólo minúsculas, dígitos y guiones."
  }
}
```

```hcl
moved {
  from = kubernetes_namespace_v1.pagos
  to   = module.equipo["pagos"].kubernetes_namespace_v1.this
}
# ... igual para resource_quota_v1 y limit_range_v1, y para catalogo y envios
```

```bash
terraform init && terraform plan    # 9 "has moved to", 3 to add (soporte), 0 to destroy
terraform apply
terraform plan -detailed-exitcode   # 0
```

La solución completa está en `solve.sh`.

## Por qué

- Sin `moved`, el plan habría sido "9 to add, 9 to destroy": borrar los
  namespaces `pagos`, `catalogo` y `envios` con todo lo que contienen.
- `validation` falla en `plan`/`validate`, antes de tocar nada.
- `for_each` con un mapa: añadir o quitar un equipo sólo afecta a ese equipo.

## Más allá del lab

- Versiona los módulos (`source = "git::...//modules/equipo?ref=v1.2.0"`) o
  publícalos en un registry privado.
- Añade `terraform test` (ficheros `.tftest.hcl`) al módulo: el lab 202 lo trabaja.
- Una vez aplicados en todos los entornos, los bloques `moved` pueden borrarse.
