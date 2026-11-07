#!/usr/bin/env bash
# Lab 193: cert-manager instalado, una CA interna... y el certificado de la
# tienda nunca llega a emitirse. Tres fallos: el emisor no es visible desde el
# namespace, faltan nombres en el certificado y el pod monta otro secret.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s

kubectl apply -f /opt/certmgr/cert-manager.yaml
for d in cert-manager cert-manager-webhook cert-manager-cainjector; do
  kubectl -n cert-manager rollout status deploy/$d --timeout=300s
done
M=/home/analista/manifiestos
mkdir -p $M

cat > $M/01-ca.yaml <<'YML'
# CA interna: una raíz autofirmada que firma el certificado de la CA de la tienda.
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata: {name: raiz-autofirmada}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: ca-tienda, namespace: cert-manager}
spec:
  isCA: true
  commonName: CA interna de la tienda
  secretName: ca-tienda
  duration: 87600h
  privateKey: {algorithm: ECDSA, size: 256}
  issuerRef: {name: raiz-autofirmada, kind: ClusterIssuer, group: cert-manager.io}
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata: {name: ca-tienda, namespace: cert-manager}
spec:
  ca: {secretName: ca-tienda}
YML
# El webhook tarda un poco en aceptar objetos después de arrancar.
for _ in $(seq 1 60); do kubectl apply -f $M/01-ca.yaml >/dev/null 2>&1 && break; sleep 3; done
kubectl apply -f $M/01-ca.yaml
kubectl -n cert-manager wait --for=condition=Ready certificate/ca-tienda --timeout=120s

kubectl create namespace tienda
for _ in $(seq 1 60); do kubectl -n tienda get sa default >/dev/null 2>&1 && break; sleep 1; done
cat > $M/02-certificado.yaml <<'YML'
apiVersion: cert-manager.io/v1
kind: Certificate
metadata: {name: web, namespace: tienda}
spec:
  secretName: web-tls
  dnsNames: [www.tienda.local]
  duration: 2160h
  renewBefore: 360h
  privateKey: {algorithm: ECDSA, size: 256, rotationPolicy: Always}
  issuerRef: {name: ca-tienda, kind: Issuer, group: cert-manager.io}
YML
cat > $M/03-web.yaml <<'YML'
apiVersion: v1
kind: ConfigMap
metadata: {name: nginx-tls, namespace: tienda}
data:
  default.conf: |
    server {
      listen 443 ssl;
      ssl_certificate     /tls/tls.crt;
      ssl_certificate_key /tls/tls.key;
      location / { return 200 "tienda ok\n"; }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: tienda, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: tienda}}
  template:
    metadata: {labels: {app: tienda}}
    spec:
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports: [{containerPort: 443}]
        volumeMounts:
        - {name: conf, mountPath: /etc/nginx/conf.d}
        - {name: tls, mountPath: /tls, readOnly: true}
        resources: {requests: {cpu: 10m, memory: 16Mi}, limits: {memory: 64Mi}}
      volumes:
      - name: conf
        configMap: {name: nginx-tls}
      - name: tls
        secret: {secretName: tienda-tls}
---
apiVersion: v1
kind: Service
metadata: {name: tienda, namespace: tienda}
spec:
  selector: {app: tienda}
  ports: [{port: 443, targetPort: 443}]
YML
kubectl apply -f $M/02-certificado.yaml -f $M/03-web.yaml
chown -R analista:analista $M

cat > /usr/local/bin/probar-tls <<'SH'
#!/usr/bin/env bash
# probar-tls [nombre] — HTTPS a la tienda verificando con la CA interna.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
N=${1:-tienda.local}
IP=$(kubectl -n tienda get svc tienda -o jsonpath='{.spec.clusterIP}')
kubectl -n cert-manager get secret ca-tienda -o jsonpath='{.data.ca\.crt}' | base64 -d > /tmp/ca-tienda.crt
curl -sS --max-time 5 --cacert /tmp/ca-tienda.crt --resolve "$N:443:$IP" "https://$N/"
SH
chmod 755 /usr/local/bin/probar-tls

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · cert-manager (namespace tienda)

Hay una CA interna gestionada por cert-manager (~/manifiestos/01-ca.yaml) y la
tienda debería servir HTTPS con un certificado firmado por ella. No funciona:
el pod no arranca y el certificado no se emite.

  kubectl -n tienda get certificate,certificaterequest,pods
  probar-tls tienda.local

Objetivos:
  1. Certificado "web" en Ready, emitido por la CA interna (no autofirmado).
  2. Válido para tienda.local y para tienda.tienda.svc.cluster.local.
  3. La tienda sirve HTTPS con él:
       probar-tls tienda.local
       probar-tls tienda.tienda.svc.cluster.local
  4. Renovación automática: si el secret desaparece o el certificado se
     renueva, cert-manager lo vuelve a emitir solo.
  5. Cambios guardados en ~/manifiestos/ y aplicados.

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 193 plantado."
