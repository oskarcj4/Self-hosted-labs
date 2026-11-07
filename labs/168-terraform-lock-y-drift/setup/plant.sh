#!/usr/bin/env bash
# Lab 168: Terraform gestiona la tienda en Kubernetes (proveedor kubernetes) con
# estado remoto en un backend HTTP con bloqueo.
#  - Un job de CI murió a mitad de un apply: bloqueo huérfano en el estado.
#  - Drift: alguien escaló a mano el Deployment y cambió el ConfigMap.
#  - Una ResourceQuota creada a mano con kubectl que nadie gestiona: hay que importarla.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml HOME=/root
H=/home/analista
I=$H/infra
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done

# --- Servidor de estado remoto ------------------------------------------------
install -m 0755 /opt/lab/setup/tf-state-server /usr/local/bin/tf-state-server
useradd -r -s /usr/sbin/nologin tfstate
install -d -o tfstate -g tfstate -m 0750 /var/lib/tfstate
cat > /etc/systemd/system/tf-state.service <<'U'
[Unit]
Description=Estado remoto de Terraform (backend HTTP con bloqueo)
[Service]
User=tfstate
ExecStart=/usr/local/bin/tf-state-server /var/lib/tfstate 8500
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now tf-state
for _ in $(seq 1 20); do curl -s -o /dev/null http://127.0.0.1:8500/state/x && break; sleep 1; done

# --- Código de infraestructura ---------------------------------------------------
mkdir -p $I
cat > $I/versions.tf <<'TF'
terraform {
  required_version = ">= 1.6"
  required_providers {
    kubernetes = { source = "hashicorp/kubernetes", version = "2.35.1" }
  }
  backend "http" {
    address        = "http://127.0.0.1:8500/state/tienda"
    lock_address   = "http://127.0.0.1:8500/state/tienda"
    unlock_address = "http://127.0.0.1:8500/state/tienda"
  }
}

provider "kubernetes" {
  config_path = "/etc/rancher/k3s/k3s.yaml"
}
TF
cat > $I/main.tf <<'TF'
resource "kubernetes_namespace_v1" "tienda" {
  metadata { name = "tienda" }
}

resource "kubernetes_config_map_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.tienda.metadata[0].name
  }
  data = {
    "index.html" = "<h1>Tienda</h1>\n"
  }
}

resource "kubernetes_deployment_v1" "web" {
  metadata {
    name      = "web"
    namespace = kubernetes_namespace_v1.tienda.metadata[0].name
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "web" } }
    template {
      metadata { labels = { app = "web" } }
      spec {
        container {
          name  = "web"
          image = "nginx:1.27-alpine"
          port { container_port = 80 }
          resources {
            requests = { cpu = "20m", memory = "16Mi" }
            limits   = { memory = "64Mi" }
          }
          volume_mount {
            name       = "html"
            mount_path = "/usr/share/nginx/html"
          }
        }
        volume {
          name = "html"
          config_map { name = kubernetes_config_map_v1.web.metadata[0].name }
        }
      }
    }
  }
}
TF
chown -R analista:analista $I
cd $I
runuser -u analista -- env HOME=/home/analista terraform init -input=false >/dev/null
runuser -u analista -- env HOME=/home/analista terraform apply -auto-approve -input=false >/dev/null
kubectl -n tienda rollout status deploy/web --timeout=180s

# --- Lo que pasó después --------------------------------------------------------
kubectl -n tienda scale deploy web --replicas=4
kubectl -n tienda patch configmap web --type merge -p '{"data":{"index.html":"<h1>Tienda - PRUEBA</h1>\n"}}'
kubectl -n tienda create quota cuota-tienda --hard=pods=20,requests.cpu=2,requests.memory=2Gi
LOCK_ID=$(cat /proc/sys/kernel/random/uuid)
cat > /var/lib/tfstate/tienda.lock <<J
{"ID":"$LOCK_ID","Operation":"OperationTypeApply","Info":"","Who":"ci@runner-7","Version":"1.11.4","Created":"$(date -u -d 'yesterday 22:41' '+%Y-%m-%dT%H:%M:%SZ')","Path":"tienda"}
J
chown tfstate:tfstate /var/lib/tfstate/tienda.lock

mkdir -p $H/ticket
cat > $H/ticket/INFRA-168.txt <<TXT
INFRA-168 · terraform plan falla con "Error acquiring the state lock"

Anoche (22:41) el job #812 de CI (runner-7) lanzó un terraform apply y el
runner se reinició a mitad. Desde entonces nadie puede hacer plan.
Confirmado con el equipo de CI: runner-7 no tiene ningún job en curso.
TXT
cat > $H/TAREA.txt <<'TXT'
TAREA · Terraform: bloqueo, drift e import (~/infra)

1. 'terraform plan' falla por un bloqueo huérfano (ticket ~/ticket/INFRA-168.txt).
   Comprueba de quién es, apunta su ID en ~/incidente.txt (lock_id=<ID>) y
   libéralo con terraform force-unlock.
2. Hay drift: alguien tocó a mano el clúster. Míralo con
   'terraform plan -refresh-only' y vuelve a lo que dice el código.
3. Existe una ResourceQuota 'cuota-tienda' (namespace tienda) creada a mano.
   Debe quedar gestionada por Terraform SIN recrearla: escribe su bloque
   (kubernetes_resource_quota_v1) e impórtala.
4. Al final, 'terraform plan' no debe proponer ningún cambio.

Comprueba:  bash /opt/lab/check.sh
TXT
chown -R analista:analista $H/ticket $H/TAREA.txt
echo "$LOCK_ID" > /opt/lab/.lock_id
echo "Lab 168 plantado."
