# Resolución guiada · Lab 169

:::piensa Antes de mover nada
Mira `terraform state list`. Cada línea es una **dirección**. Cuando el código
cambie, Terraform compara direcciones: si la vieja ya no existe en el código y
la nueva no está en el estado, propone destruir una y crear otra. Con un
namespace, eso borra todo lo que hay dentro.
:::

## Paso 1 · El módulo

:::pista Qué contiene
`modules/equipo/` con cuatro ficheros:

- `variables.tf`: `nombre` (con `validation` y `regex("^[a-z0-9-]+$", ...)`),
  `cpu`, `memoria`, `pods` (`default = 30`).
- `main.tf`: los tres recursos, llamados `this`, usando `var.*`.
- `outputs.tf`: `output "namespace"`.
- `versions.tf`: `required_providers` con `hashicorp/kubernetes`.
:::

## Paso 2 · La raíz con for_each

:::pista Cómo hacerlo
```hcl
locals {
  equipos = {
    pagos    = { cpu = "2", memoria = "4Gi" }
    catalogo = { cpu = "1", memoria = "2Gi" }
    envios   = { cpu = "1", memoria = "1Gi" }
  }
}
module "equipo" {
  source   = "./modules/equipo"
  for_each = local.equipos
  nombre   = each.key
  cpu      = each.value.cpu
  memoria  = each.value.memoria
}
```
Borra los `resource` del `main.tf` viejo.
:::

## Paso 3 · moved

:::pista Qué escribir
Un bloque por recurso y equipo (9 en total):
```hcl
moved {
  from = kubernetes_namespace_v1.pagos
  to   = module.equipo["pagos"].kubernetes_namespace_v1.this
}
```
`terraform plan` debe decir "has moved to" y **0 to destroy**.
:::

## Paso 4 · soporte y output

:::pista Cómo hacerlo
Una línea en `equipos`: `soporte = { cpu = "1", memoria = "1Gi" }`.
```hcl
output "namespaces" {
  value = { for k, m in module.equipo : k => m.namespace }
}
```
:::

## Cómo actuar en una situación así

- Refactor de IaC = cambiar direcciones, no recursos. Primero `plan` y lee la
  última línea: si hay `destroy` que no esperas, para.
- `moved` queda en el código y se revisa en el PR; `terraform state mv` no deja rastro.
- Usa claves estables en `for_each` (nombres), nunca índices de lista (`count`):
  quitar un elemento del medio movería todos los demás.

## Si te atascas

- "Module not installed": tras crear el módulo, `terraform init`.
- El plan aún quiere recrear algo: revisa que el nombre del recurso en el
  módulo (`this`) coincide con el `to` del `moved`.
