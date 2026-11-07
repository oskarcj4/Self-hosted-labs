# Solución — Terraform: lock y drift

```bash
cd ~/infra
terraform plan                  # Error acquiring the state lock ... ID=<ID>
echo "lock_id=<ID>" > ~/incidente.txt
terraform force-unlock <ID>     # tras confirmar que runner-7 no tiene jobs
terraform plan -refresh-only    # drift: replicas 2 -> 4, index.html cambiado
```

`quota.tf`:
```hcl
resource "kubernetes_resource_quota_v1" "tienda" {
  metadata {
    name      = "cuota-tienda"
    namespace = kubernetes_namespace_v1.tienda.metadata[0].name
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
terraform apply                 # revierte el drift e importa la cuota
terraform plan -detailed-exitcode   # 0: sin cambios
```

## Por qué

- El backend HTTP responde `423 Locked` mientras exista el bloqueo. Si el
  proceso dueño muere sin `UNLOCK`, queda para siempre: hace falta intervención
  humana, y por eso Terraform no lo quita solo.
- `-refresh-only` separa "qué cambió fuera" de "qué quiero cambiar yo".
- Un recurso creado a mano y luego declarado sin importar haría que `apply`
  intente crearlo y falle con "already exists". `import` lo adopta.

## Más allá del lab

- Ejecuta Terraform sólo desde el pipeline y con `-lock-timeout=5m`.
- `terraform plan -refresh-only -detailed-exitcode` programado = detector de drift.
- Bloques `import` (Terraform 1.5+) en lugar de `terraform import`: quedan en
  el código y se revisan en el PR.
