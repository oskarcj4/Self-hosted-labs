# Terraform: lock y drift

> IaC · Terraform · estado remoto · force-unlock · plan -refresh-only · import

## Escenario

`~/infra` gestiona con Terraform (proveedor `kubernetes`) la tienda del clúster
k3s del lab. El estado vive en un **backend HTTP con bloqueo** (como el de
GitLab) en `127.0.0.1:8500`.

Esta mañana:

- `terraform plan` falla: **Error acquiring the state lock**. Un job de CI se
  murió a mitad de un `apply` anoche (`~/ticket/INFRA-168.txt`).
- Alguien tocó el clúster a mano (**drift**).
- Hay una `ResourceQuota` `cuota-tienda` creada con `kubectl` que Terraform no
  conoce.

Conceptos:

- El **bloqueo** evita que dos `apply` escriban el estado a la vez. Si el
  proceso que lo tomó muere, queda huérfano. `terraform force-unlock <ID>` lo
  quita, **sólo** tras confirmar que no hay nadie trabajando.
- **Drift** = lo real ya no coincide con el estado. `terraform plan
  -refresh-only` lo enseña sin proponer cambios de código.
- **import** = meter en el estado un recurso que ya existe, sin recrearlo.

## Objetivos

1. `~/incidente.txt` con `lock_id=<ID del bloqueo huérfano>` y el bloqueo liberado.
2. Drift revertido: el clúster vuelve a lo que dice el código.
3. `cuota-tienda` gestionada por Terraform (bloque `kubernetes_resource_quota_v1`
   + import), con los mismos valores que tiene hoy.
4. `terraform plan` sin cambios pendientes.

## Pistas

```bash
cd ~/infra
terraform plan                      # el error muestra el ID del bloqueo (línea ID=...)
terraform force-unlock <ID>
terraform plan -refresh-only
terraform apply
kubectl -n tienda get resourcequota cuota-tienda -o yaml
terraform import kubernetes_resource_quota_v1.tienda tienda/cuota-tienda
# o un bloque  import { to = ... , id = "tienda/cuota-tienda" }  y terraform apply
terraform plan -detailed-exitcode   # 0 = sin cambios
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
