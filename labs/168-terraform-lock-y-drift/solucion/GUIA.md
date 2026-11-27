# Resolución guiada · Lab 168

:::piensa El bloqueo protege; quitarlo es una decisión
`force-unlock` no "arregla" nada: sólo quita el candado. Si hubiera un apply
vivo, dos procesos escribirían el estado a la vez y lo corromperían. Confirma
antes (aquí, el ticket dice que runner-7 no tiene jobs).
:::

## Paso 1 · El bloqueo

:::pista Qué mirar
```bash
cd ~/infra && terraform plan
# Error message: HTTP remote state already locked:
# ID=xxxxxxxx-....      <- el bloqueo que existe
```
Debajo, "Lock Info" muestra la información de **tu** intento, no la del dueño.
:::

:::pista Cómo hacerlo
```bash
echo "lock_id=<ID>" > ~/incidente.txt
terraform force-unlock <ID>
```
:::

## Paso 2 · Drift

:::pista Qué mirar
```bash
terraform plan -refresh-only
terraform apply
```
`-refresh-only` compara el estado guardado con lo que hay de verdad en el
clúster, sin proponer cambios: es la forma de **ver** el *drift* (lo que
alguien cambió a mano). **Qué deberías ver:** réplicas 2→4 y el `index.html`
cambiado. Como el código es la verdad, un `apply` normal lo devuelve a su
sitio (pide confirmar con `yes`).
:::

## Paso 3 · Import

:::pista Cómo hacerlo
Primero mira los valores reales de la cuota que existe en el clúster y que
Terraform no gestiona:
```bash
kubectl -n tienda get resourcequota cuota-tienda -o yaml
```
Escribe el recurso con **esos** valores y un bloque `import`:
```hcl
resource "kubernetes_resource_quota_v1" "tienda" {
  metadata {
    name      = "cuota-tienda"
    namespace = "tienda"
  }
  spec {
    hard = {
      pods              = "20"
      "requests.cpu"    = "2"
      "requests.memory" = "2Gi"
    }
  }
}

import {
  to = kubernetes_resource_quota_v1.tienda
  id = "tienda/cuota-tienda"
}
```
```bash
terraform plan
terraform apply
terraform plan
```
- El bloque `import` le dice a Terraform: "este recurso ya existe; apúntalo en
  el estado con esta dirección". El `id` lo define cada proveedor; para el de
  Kubernetes es `namespace/nombre`.
- **Qué deberías ver:** en el primer plan, `1 to import, 0 to add, 0 to
  change`; y el último, `No changes`. Si propone cambios, tus valores no
  coinciden con los reales.

Después del `apply`, el bloque `import` puede quedarse o borrarse.
:::

## Cómo actuar en una situación así

- Bloqueo: ¿quién?, ¿cuándo?, ¿sigue vivo? → sólo entonces force-unlock.
- Drift: decide si el código o el clúster tienen razón. Si el cambio era bueno, al código.
- Import: escribe el bloque con los valores reales, importa y comprueba que `plan` no cambia nada.

## Si te atascas

- `plan` tras importar quiere cambiar la cuota: tus valores no coinciden con
  los reales (`kubectl -n tienda get quota cuota-tienda -o yaml`).
- `force-unlock` pide confirmación: escribe `yes` (o usa `-force`).
