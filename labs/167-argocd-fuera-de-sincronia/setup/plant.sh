#!/usr/bin/env bash
# Lab 167: Argo CD (core) despliega 'tienda' desde un repo git. Durante una
# guardia alguien tocó el clúster a mano: escaló a 5, activó un modo debug y
# cambió el mensaje del ConfigMap (este último cambio es bueno: lo pidió negocio).
# La app queda OutOfSync. Sin auto-sync ni self-heal.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml HOME=/root
H=/home/analista
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done

# --- Servidor git (HTTP "tonto" de solo lectura para Argo CD) -----------------
IP=$(kubectl get node nodo1 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
mkdir -p /srv/git
git init -q --bare -b main /srv/git/tienda.git
cp /srv/git/tienda.git/hooks/post-update.sample /srv/git/tienda.git/hooks/post-update
chmod +x /srv/git/tienda.git/hooks/post-update
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
runuser -u analista -- git clone -q /srv/git/tienda.git $W 2>/dev/null
runuser -u analista -- git -C $W config user.name "Analista"
runuser -u analista -- git -C $W config user.email analista@tienda.local
mkdir -p $W/apps/tienda
cat > $W/apps/tienda/tienda.yaml <<'YML'
apiVersion: v1
kind: ConfigMap
metadata: {name: tienda-web}
data:
  index.html: |
    <h1>Bienvenido a la tienda</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: tienda}
spec:
  replicas: 2
  selector: {matchLabels: {app: tienda}}
  template:
    metadata: {labels: {app: tienda}}
    spec:
      containers:
      - name: web
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
        readinessProbe: {httpGet: {path: /, port: 80}, periodSeconds: 5}
        resources:
          requests: {cpu: 20m, memory: 16Mi}
          limits:   {memory: 64Mi}
        volumeMounts: [{name: html, mountPath: /usr/share/nginx/html}]
      volumes:
      - name: html
        configMap: {name: tienda-web}
---
apiVersion: v1
kind: Service
metadata: {name: tienda}
spec:
  selector: {app: tienda}
  ports: [{port: 80, targetPort: 80}]
YML
chown -R analista:analista $W
runuser -u analista -- git -C $W add -A
runuser -u analista -- git -C $W commit -qm "tienda: despliegue inicial"
runuser -u analista -- git -C $W push -q origin main

# --- Argo CD core ---------------------------------------------------------------
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f /opt/argocd/core-install.yaml >/dev/null
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=600s
kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=600s
kubectl -n argocd rollout status deploy/argocd-redis --timeout=600s

cat <<YML | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata: {name: tienda, namespace: argocd}
spec:
  project: default
  source:
    repoURL: http://$IP:8000/tienda.git
    targetRevision: main
    path: apps/tienda
  destination:
    server: https://kubernetes.default.svc
    namespace: tienda
  syncPolicy:
    syncOptions: [CreateNamespace=true]
YML
sync(){ kubectl -n argocd patch app tienda --type merge \
  -p '{"operation":{"initiatedBy":{"username":"plant"},"sync":{"revision":"main"}}}' >/dev/null; }
for _ in $(seq 1 60); do
  [ "$(kubectl -n argocd get app tienda -o jsonpath='{.status.sync.status}' 2>/dev/null)" = Synced ] && break
  sync 2>/dev/null || true; sleep 5
done
kubectl -n tienda rollout status deploy/tienda --timeout=300s

# --- La guardia de anoche: cambios a mano en el clúster -------------------------
kubectl -n tienda scale deploy tienda --replicas=5
kubectl -n tienda set env deploy/tienda MODO_DEBUG=1
kubectl -n tienda patch configmap tienda-web --type merge \
  -p '{"data":{"index.html":"<h1>Bienvenido a la tienda</h1>\n<p>Envío gratis hoy</p>\n"}}'
kubectl -n argocd annotate app tienda argocd.argoproj.io/refresh=normal --overwrite >/dev/null
for _ in $(seq 1 30); do
  [ "$(kubectl -n argocd get app tienda -o jsonpath='{.status.sync.status}')" = OutOfSync ] && break; sleep 3
done

# CLI de Argo CD en modo core para analista: su kubeconfig con namespace argocd.
mkdir -p $H/.kube
sed 's/^\(\s*\)cluster: default$/\1cluster: default\n\1namespace: argocd/' /etc/rancher/k3s/k3s.yaml > $H/.kube/config
chown -R analista:analista $H/.kube; chmod 0600 $H/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> $H/.bashrc

cat > $H/TAREA.txt <<'TXT'
TAREA · Argo CD fuera de sincronía

Argo CD despliega 'tienda' desde git (~/gitops, apps/tienda). Anoche, durante
la guardia, alguien tocó el clúster a mano y la app está OutOfSync.
Según el ticket de la guardia:
  - "escalé a 5 para aguantar"           -> ya no hace falta: vuelve a lo de git
  - "activé MODO_DEBUG para investigar"  -> se olvidó quitarlo: fuera
  - "cambié el mensaje: Envío gratis hoy" -> lo pidió negocio: SE QUEDA

1. Averigua qué recursos tienen drift y apúntalos en ~/drift.txt
   (uno por línea, p. ej. deployment/xxx).
2. El cambio bueno no puede vivir sólo en el clúster: llévalo a git
   (commit + push en ~/gitops).
3. Sincroniza: app Synced y Healthy, con lo que diga git.
4. Que no vuelva a pasar: syncPolicy.automated con selfHeal y prune.
   El check escalará a mano el Deployment y esperará que Argo CD lo revierta.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista $H/TAREA.txt
echo "Lab 167 plantado."
