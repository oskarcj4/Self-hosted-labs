# Terraform: módulos reutilizables

> IaC · módulos · variables · validation · outputs · for_each · moved

## Escenario

`~/infra/main.tf` da de alta tres equipos (`pagos`, `catalogo`, `envios`) en el
clúster k3s del lab. Cada equipo es el **mismo bloque copiado y pegado**:
namespace + `ResourceQuota` + `LimitRange`, cambiando a mano nombre y cuotas.
Mañana llega `soporte`.

Un **módulo** es una carpeta de `.tf` con entradas (`variable`), salidas
(`output`) y sus propios requisitos de proveedor. Se llama con
`module "x" { source = "./modules/equipo" ... }` y, con `for_each`, una vez
por elemento de un mapa.

Al mover recursos a un módulo cambia su **dirección** en el estado
(`kubernetes_namespace_v1.pagos` → `module.equipo["pagos"].kubernetes_namespace_v1.this`).
Sin decirle nada, Terraform cree que uno desaparece y otro aparece:
**destruye y recrea** (¡y borrar un namespace borra todo lo que contiene!).
Los bloques `moved { from = ... to = ... }` lo evitan.

## Objetivos

1. Módulo `modules/equipo` con `variables.tf` (`nombre` con `validation`:
   minúsculas, dígitos y guiones; `cpu`; `memoria`; `pods` = 30 por defecto),
   `main.tf`, `outputs.tf` (output `namespace`) y `versions.tf`.
2. Raíz: el módulo usado **una vez** con `for_each` sobre `equipos`; sin
   recursos `kubernetes_*` sueltos.
3. Refactor **sin recrear** los namespaces existentes (`moved`).
4. Alta de `soporte` (cpu `1`, memoria `1Gi`) con una entrada nueva.
5. Output raíz `namespaces`.
6. `terraform plan` sin cambios al final.

## Pistas

```bash
cd ~/infra
terraform state list
terraform plan                 # ¿ves "must be replaced" o "destroy"? -> faltan moved
terraform validate
terraform output namespaces
```

```hcl
moved {
  from = kubernetes_namespace_v1.pagos
  to   = module.equipo["pagos"].kubernetes_namespace_v1.this
}
```

```hcl
variable "nombre" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nombre))
    error_message = "nombre: sólo minúsculas, dígitos y guiones."
  }
}
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
