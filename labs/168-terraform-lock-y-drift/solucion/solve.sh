#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/infra
ID=$(terraform plan -no-color -input=false -lock-timeout=1s 2>&1 | sed -n 's/^.*ID=\([0-9a-f-]\{36\}\).*$/\1/p' | head -1)
echo "Bloqueo huérfano: $ID"
echo "lock_id=$ID" > ~/incidente.txt
terraform force-unlock -force "$ID"

cat > quota.tf <<'TF'
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
TF
terraform plan -refresh-only -input=false -no-color | tail -20
terraform apply -auto-approve -input=false
terraform plan -detailed-exitcode -input=false
echo "solve.sh completado."
