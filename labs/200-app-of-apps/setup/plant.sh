#!/usr/bin/env bash
# Lab 200: Argo CD con Applications creadas a mano (no están en git): tienda
# vale, pagos apunta a una rama vieja y catalogo nunca se dio de alta.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml HOME=/root
H=/home/analista
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done

# --- Servidor git (HTTP "tonto" de solo lectura para Argo CD) -----------------
IP=$(kubectl get node nodo1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
echo "$IP" > /opt/lab/git-ip
mkdir -p /srv/git
git init -q --bare -b main /srv/git/plataforma.git
cp /srv/git/plataforma.git/hooks/post-update.sample /srv/git/plataforma.git/hooks/post-update
chmod +x /srv/git/plataforma.git/hooks/post-update
chown -R analista:analista /srv/git
cat > /etc/systemd/system/git-http.service <<'U'
[Unit]
Description=Repositorio git de GitOps (HTTP de solo lectura)
[Service]
ExecStart=/usr/bin/python3 -m http.server 8000 --directory /srv/git
Restart=always
[Install]
WantedBy=multi-user.target
U
systemctl daemon-reload && systemctl enable --now git-http

W=$H/gitops
G(){ runuser -u analista -- git -C $W "$@"; }
runuser -u analista -- git clone -q /srv/git/plataforma.git $W 2>/dev/null
G config user.name "Analista"; G config user.email analista@tienda.local
# app <nombre> <réplicas> <mensaje>
app(){
  mkdir -p $W/apps/$1
  cat > $W/apps/$1/$1.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: $1}
spec:
  replicas: $2
  selector: {matchLabels: {app: $1}}
  template:
    metadata: {labels: {app: $1}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "mkdir -p /www && echo '$3' > /www/index.html && exec httpd -f -p 8080 -h /www"]
        readinessProbe: {httpGet: {path: /, port: 8080}, periodSeconds: 3}
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: $1}
spec:
  selector: {app: $1}
  ports: [{port: 80, targetPort: 8080}]
YML
}
app tienda 2 "tienda v1"
app pagos 1 "pagos v1"
chown -R analista:analista $W
G add -A; G commit -qm "tienda y pagos v1"; G push -q origin main
# Rama de una prueba antigua que nunca se borró.
G checkout -qb prueba-pagos; G push -q origin prueba-pagos; G checkout -q main
app pagos 2 "pagos v2"
app catalogo 2 "catalogo v1"
chown -R analista:analista $W
G add -A; G commit -qm "pagos v2 (2 réplicas) y nuevo catalogo"; G push -q origin main

# --- Argo CD core ---------------------------------------------------------------
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f /opt/argocd/core-install.yaml >/dev/null
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s
kubectl -n argocd rollout status deploy/argocd-redis --timeout=600s

# Las Applications, creadas a mano un día con kubectl (no están en ningún repo).
alta(){ cat <<YML | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: $1, namespace: argocd}
spec:
  project: default
  source: {repoURL: http://$IP:8000/plataforma.git, targetRevision: $2, path: apps/$1}
  destination: {server: https://kubernetes.default.svc, namespace: $1}
  syncPolicy:
    syncOptions: [CreateNamespace=true]
YML
}
alta tienda main
alta pagos prueba-pagos
for a in tienda pagos; do
  for _ in $(seq 1 60); do
    [ "$(kubectl -n argocd get app $a -o jsonpath='{.status.sync.status}' 2>/dev/null)" = Synced ] && break
    kubectl -n argocd patch app $a --type merge \
      -p '{"operation":{"initiatedBy":{"username":"plant"},"sync":{}}}' >/dev/null 2>&1 || true
    sleep 5
  done
done
kubectl -n tienda rollout status deploy/tienda --timeout=300s
kubectl -n pagos rollout status deploy/pagos --timeout=300s

# CLI de Argo CD en modo core para analista.
mkdir -p $H/.kube
sed 's/^\(\s*\)cluster: default$/\1cluster: default\n\1namespace: argocd/' /etc/rancher/k3s/k3s.yaml > $H/.kube/config
chown -R analista:analista $H/.kube; chmod 0600 $H/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> $H/.bashrc

cat > $H/TAREA.txt <<TXT
TAREA · App of Apps

Argo CD despliega desde el repo ~/gitops (http://$IP:8000/plataforma.git).
Pero las Applications de Argo CD se crearon a mano con kubectl un día, y no
están en ningún repo:

  kubectl -n argocd get applications
  - tienda:   bien.
  - pagos:    sigue la rama "prueba-pagos" de una prueba antigua (sirve
              "pagos v1" con 1 réplica; main ya tiene pagos v2).
  - catalogo: está en apps/catalogo desde hace semanas... y nadie la dio de alta.

Objetivo: patrón "App of Apps".
  1. Las Applications de tienda, pagos y catalogo, declaradas en git en
     ~/gitops/argocd/ (namespace argocd), todas desde main, con sync
     automático (prune + selfHeal) y CreateNamespace.
  2. Una Application raíz "raiz" (en argocd) que despliega ese directorio,
     también con sync automático (prune + selfHeal). Guárdala en
     ~/gitops/raiz.yaml y aplícala una vez con kubectl: es lo único que se
     crea a mano.
  3. Resultado: las tres apps Synced y Healthy, pagos sirviendo v2.
  4. Dar de alta (o de baja) una app es sólo un commit en argocd/.
     El check lo probará añadiendo y quitando una Application.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 200 plantado."
