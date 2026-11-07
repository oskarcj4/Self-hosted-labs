#!/usr/bin/env bash
# Lab 169: tres equipos con el mismo bloque copiado y pegado (namespace + cuota
# + LimitRange). El alumno lo convierte en un módulo con variables, validación
# y salidas, lo usa con for_each, lo refactoriza SIN recrear nada (moved) y
# da de alta un cuarto equipo añadiendo una línea.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml HOME=/root
H=/home/analista
I=$H/infra
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done

mkdir -p $I
cat > $I/versions.tf <<'TF'
terraform {
  required_version = ">= 1.6"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "2.35.1" }
  }
}

provider "kubernetes" {
  config_path = "/etc/rancher/k3s/k3s.yaml"
}
TF
{
for e in "pagos 2 4Gi" "catalogo 1 2Gi" "envios 1 1Gi"; do
  set -- $e
  cat <<TF
# ---- equipo $1 (copiado del anterior y cambiado a mano) ----
resource "kubernetes_namespace_v1" "$1" {
  metadata {
    name   = "$1"
    labels = { equipo = "$1" }
  }
}

resource "kubernetes_resource_quota_v1" "$1" {
  metadata {
    name      = "cuota"
    namespace = kubernetes_namespace_v1.$1.metadata[0].name
  }
  spec {
    hard = {
      "requests.cpu"    = "$2"
      "requests.memory" = "$3"
      pods              = "30"
    }
  }
}

resource "kubernetes_limit_range_v1" "$1" {
  metadata {
    name      = "defaults"
    namespace = kubernetes_namespace_v1.$1.metadata[0].name
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
done
} > $I/main.tf
chown -R analista:analista $I
cd $I
runuser -u analista -- env HOME=$H terraform init -input=false >/dev/null
runuser -u analista -- env HOME=$H terraform apply -auto-approve -input=false >/dev/null
for n in pagos catalogo envios; do
  echo "$n $(kubectl get ns $n -o jsonpath='{.metadata.uid}')"
done > /opt/lab/.uids

cat > $H/TAREA.txt <<'TXT'
TAREA · Terraform: módulos reutilizables (~/infra)

main.tf repite el mismo bloque (namespace + cuota + LimitRange) para cada
equipo. Mañana llega el equipo "soporte" y alguien volverá a copiar y pegar.

1. Crea el módulo ~/infra/modules/equipo:
   - variables.tf: nombre (string, con validation: sólo minúsculas, dígitos y
     guiones), cpu (string), memoria (string), pods (number, por defecto 30).
   - main.tf: namespace (etiqueta equipo=<nombre>), ResourceQuota "cuota" y
     LimitRange "defaults" (los mismos valores que hoy).
   - outputs.tf: output "namespace" con el nombre del namespace.
   - versions.tf: required_providers del módulo.
2. En la raíz, usa el módulo UNA vez con for_each sobre una variable/local
   "equipos" (pagos 2/4Gi, catalogo 1/2Gi, envios 1/1Gi). Sin recursos
   kubernetes_* sueltos en la raíz.
3. Refactoriza SIN destruir nada: los namespaces actuales no se recrean
   (bloques moved). 'terraform plan' no debe proponer destroy.
4. Añade el equipo "soporte" (cpu 1, memoria 1Gi) con UNA entrada nueva y aplica.
5. Output raíz "namespaces" con la lista/mapa de namespaces creados.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 169 plantado."
