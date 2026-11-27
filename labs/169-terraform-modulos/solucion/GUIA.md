# Resolución guiada · Lab 169

:::piensa Terraform compara direcciones, no recursos
Cada recurso que Terraform gestiona tiene una **dirección** en su estado
(`kubernetes_namespace_v1.pagos`). Si cambias el código y esa dirección
desaparece mientras aparece otra nueva
(`module.equipo["pagos"].kubernetes_namespace_v1.this`), Terraform no sabe que
son el mismo: propone **destruir** el viejo y **crear** el nuevo. Con un
namespace, destruir significa borrar todo lo que hay dentro. Los bloques
`moved` le dicen "es el mismo, sólo ha cambiado de dirección".
:::

**El plan:** (1) ver el estado actual, (2) crear el módulo, (3) usarlo con
`for_each`, (4) declarar los `moved`, (5) planificar y aplicar, y (6) dar de
alta `soporte`.

## Paso 1 · ¿Qué hay en el estado?

:::pista Cómo hacerlo
```bash
cd ~/infra
cat main.tf
terraform state list
```
`terraform state list` lista las direcciones de todo lo que Terraform gestiona.

**Qué deberías ver:** nueve direcciones, tres por equipo:
`kubernetes_namespace_v1.pagos`, `kubernetes_resource_quota_v1.pagos`,
`kubernetes_limit_range_v1.pagos`, y lo mismo para `catalogo` y `envios`. En
`main.tf`, el mismo bloque copiado tres veces.
:::

## Paso 2 · El módulo

**Objetivo:** el bloque repetido, escrito una sola vez y con variables.

:::pista Cómo hacerlo
Un módulo es una carpeta con ficheros `.tf`. Crea `modules/equipo/` con
cuatro ficheros:

`modules/equipo/versions.tf` (qué proveedor necesita el módulo):
```hcl
terraform {
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "2.35.1" }
  }
}
```

`modules/equipo/variables.tf` (sus entradas):
```hcl
variable "nombre" {
  type = string
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.nombre))
    error_message = "nombre: sólo minúsculas, dígitos y guiones."
  }
}
variable "cpu" { type = string }
variable "memoria" { type = string }
variable "pods" {
  type    = number
  default = 30
}
```
- `validation` comprueba el valor al hacer `plan`: un nombre inválido para
  Kubernetes falla aquí, con un mensaje claro, en vez de en el clúster.
- `regex(…)` lanza un error si no encaja; `can(…)` convierte ese error en
  `false`.
- `default = 30`: si quien usa el módulo no da `pods`, vale 30.

`modules/equipo/main.tf`: los tres recursos del `main.tf` original,
llamados `this` y con `var.*` en lugar de los valores. Tienen que ser
**idénticos** a los que ya existen (mismos nombres `cuota` y `defaults`,
mismas etiquetas y límites); si no, el plan propondrá cambiarlos.
```hcl
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
```
`this` es la convención para "el único recurso de este tipo en el módulo".
`tostring(var.pods)`: la cuota espera texto y la variable es un número.

`modules/equipo/outputs.tf` (sus salidas):
```hcl
output "namespace" {
  value = kubernetes_namespace_v1.this.metadata[0].name
}
```
:::

## Paso 3 · La raíz con `for_each`

**Objetivo:** que `main.tf` diga **qué** equipos hay, no **cómo** se crean.

:::pista Cómo hacerlo
Sustituye `~/infra/main.tf` entero (no toques `versions.tf`, que configura el
proveedor):
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

  nombre  = each.key
  cpu     = each.value.cpu
  memoria = each.value.memoria
}

output "namespaces" {
  value = { for k, m in module.equipo : k => m.namespace }
}
```
- `locals` define valores con nombre dentro de la configuración.
- `for_each` crea una instancia del módulo por cada elemento del mapa;
  `each.key` es la clave (`pagos`) y `each.value` su valor.
- El `output` recorre las instancias (`for k, m in …`) y construye un mapa
  `equipo => namespace`.
:::

## Paso 4 · Los `moved`

**Objetivo:** decirle a Terraform que los nueve recursos existentes son los
mismos, en su nueva dirección.

:::pista Cómo hacerlo
Un bloque por recurso y equipo (9). En lugar de escribirlos a mano, genéralos
en `moved.tf`:
```bash
for e in pagos catalogo envios; do
  for r in namespace_v1 resource_quota_v1 limit_range_v1; do
    printf 'moved {\n  from = kubernetes_%s.%s\n  to   = module.equipo["%s"].kubernetes_%s.this\n}\n\n' "$r" "$e" "$e" "$r"
  done
done > moved.tf
cat moved.tf
```
Cada bloque queda así:
```hcl
moved {
  from = kubernetes_namespace_v1.pagos
  to   = module.equipo["pagos"].kubernetes_namespace_v1.this
}
```
:::

## Paso 5 · Planifica y aplica

```bash
terraform init
terraform validate
terraform plan
```
- `init` es necesario cada vez que añades un módulo: lo registra en
  `.terraform/`. Sin él, `Module not installed`.
- `validate` comprueba la sintaxis y las referencias sin tocar el clúster.

**Qué deberías ver** en el plan: nueve líneas `has moved to` y, al final,
`0 to add, 0 to change, 0 to destroy`. Si aparece algún `destroy` o
`must be replaced`, **para**: falta un `moved` o un recurso del módulo no es
idéntico al original. Cuando esté limpio:
```bash
terraform apply
```
`apply` vuelve a enseñar el plan y pide `yes`. Así el estado guarda ya las
direcciones nuevas.

## Paso 6 · Alta de `soporte`

```bash
nano main.tf        # añade en equipos:  soporte  = { cpu = "1", memoria = "1Gi" }
terraform plan      # 3 to add, 0 to destroy
terraform apply
terraform output namespaces
terraform plan      # No changes.
bash /opt/lab/check.sh
```
Dar de alta un equipo es ahora **una línea**.

## Cómo actuar en una situación así

- Refactorizar infraestructura como código es cambiar direcciones, no
  recursos. Lee siempre la última línea del `plan`: un `destroy` que no
  esperas es una alarma.
- `moved` queda en el código y se revisa en el pull request;
  `terraform state mv` hace lo mismo a mano, sin dejar rastro.
- Usa `for_each` con claves estables (nombres), no `count` con índices: quitar
  un elemento del medio renumeraría y recrearía todos los siguientes.

## Si te atascas

- **`Module not installed`:** `terraform init`.
- **El plan quiere recrear algo:** revisa que el `to` del `moved` usa `this` y
  la clave correcta (`["pagos"]`), y que el recurso del módulo es idéntico al
  original.
- **`Duplicate provider configuration`:** pusiste un bloque `provider` dentro
  del módulo. El proveedor se configura sólo en la raíz (`versions.tf`).
- **El plan quiere cambiar la cuota (`~ update in-place`):** algún valor del
  módulo no coincide (por ejemplo `pods = 30` como número en vez de texto).
