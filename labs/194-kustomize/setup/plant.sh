#!/usr/bin/env bash
# Lab 194: la misma app copiada a mano en dev/ y prod/, con deriva entre las
# copias (prod perdió la readinessProbe). Hay que pasarla a Kustomize.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
for ns in dev prod; do
  kubectl create namespace $ns
  for _ in $(seq 1 60); do kubectl -n $ns get sa default >/dev/null 2>&1 && break; sleep 1; done
done

A=/home/analista/app
mkdir -p $A/dev $A/prod
# copia <entorno> <réplicas> <memoria> <con-probe 0|1> <LOG_LEVEL>
copia(){
  local e=$1 r=$2 m=$3 p=$4 l=$5 probe=""
  [ "$p" = 1 ] && probe='
        readinessProbe:
          httpGet: {path: /, port: 80}
          periodSeconds: 5'
  cat > $A/$e/configmap.yaml <<YML
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
  namespace: $e
  labels: {app: web, entorno: $e}
data:
  LOG_LEVEL: $l
  index.html: |
    web entorno=$e
YML
  cat > $A/$e/deployment.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  namespace: $e
  labels: {app: web, entorno: $e}
spec:
  replicas: $r
  selector:
    matchLabels: {app: web}
  template:
    metadata:
      labels: {app: web, entorno: $e}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports: [{containerPort: 80}]
        env:
        - name: LOG_LEVEL
          valueFrom: {configMapKeyRef: {name: web-config, key: LOG_LEVEL}}$probe
        resources:
          requests: {cpu: 10m, memory: 16Mi}
          limits: {memory: $m}
        volumeMounts:
        - {name: html, mountPath: /usr/share/nginx/html}
      volumes:
      - name: html
        configMap:
          name: web-config
          items: [{key: index.html, path: index.html}]
YML
  cat > $A/$e/service.yaml <<YML
apiVersion: v1
kind: Service
metadata:
  name: web
  namespace: $e
  labels: {app: web, entorno: $e}
spec:
  selector: {app: web}
  ports: [{port: 80, targetPort: 80}]
YML
}
copia dev 1 64Mi 1 debug
copia prod 3 128Mi 0 info
kubectl apply -f $A/dev -f $A/prod
kubectl -n dev rollout status deploy/web --timeout=180s
kubectl -n prod rollout status deploy/web --timeout=180s
chown -R analista:analista $A

cat > /usr/local/bin/probar-web <<'SH'
#!/usr/bin/env bash
# probar-web — qué sirve cada entorno.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for e in dev prod; do
  IP=$(kubectl -n $e get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  printf '  %-5s -> %s\n' $e "$(curl -s --max-time 3 http://$IP/ 2>/dev/null || echo 'sin respuesta')"
done
SH
chmod 755 /usr/local/bin/probar-web

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · De copiar y pegar a Kustomize

~/app/dev/ y ~/app/prod/ son la misma app copiada a mano. Ya divergen: alguien
quitó la readinessProbe sólo en prod, y nadie se dio cuenta.

Reorganízalo con Kustomize (kubectl lo trae: kubectl kustomize / apply -k):

  ~/app/base/                 Deployment, Service y config común. Una sola vez.
  ~/app/overlays/dev/         sólo lo que cambia en dev
  ~/app/overlays/prod/        sólo lo que cambia en prod

Lo que cambia por entorno:
              dev        prod
  namespace   dev        prod
  réplicas    1          3
  memoria     64Mi       128Mi
  LOG_LEVEL   debug      info
  index.html  "web entorno=dev"   "web entorno=prod"
  etiqueta    entorno: dev        entorno: prod

Además:
  - las dos tienen readinessProbe (vive en la base);
  - la config la genera Kustomize (configMapGenerator), con sufijo hash: así
    un cambio de config provoca un rollout;
  - la imagen y el Service sólo se declaran en la base;
  - borra ~/app/dev y ~/app/prod cuando ya no los necesites;
  - aplica los dos entornos con kubectl apply -k.

  kubectl kustomize ~/app/overlays/prod      # ver lo que se generaría
  probar-web

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 194 plantado."
