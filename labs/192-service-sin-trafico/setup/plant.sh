#!/usr/bin/env bash
# Lab 192: cuatro Services que no llevan tráfico a sus pods, cada uno por una
# causa distinta: selector, targetPort, readiness y puerto con nombre.
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s
kubectl create namespace tienda
for _ in $(seq 1 60); do kubectl -n tienda get sa default >/dev/null 2>&1 && break; sleep 1; done

M=/home/analista/manifiestos
mkdir -p $M
# web <nombre> <puerto> -> contenedor busybox httpd que sirve "<nombre> ok" en / y en /salud
web(){ echo "mkdir -p /www && echo '$1 ok' > /www/index.html && cp /www/index.html /www/salud && exec httpd -f -p $2 -h /www"; }

cat > $M/catalogo.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: catalogo, namespace: tienda}
spec:
  replicas: 2
  selector: {matchLabels: {app: catalogo}}
  template:
    metadata: {labels: {app: catalogo, equipo: productos}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "$(web catalogo 8080)"]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: catalogo, namespace: tienda}
spec:
  selector: {app: catalog, equipo: productos}
  ports: [{port: 80, targetPort: 8080}]
YML

cat > $M/pagos.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: pagos, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: pagos}}
  template:
    metadata: {labels: {app: pagos}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "$(web pagos 8080)"]
        ports: [{containerPort: 8080}]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: pagos, namespace: tienda}
spec:
  selector: {app: pagos}
  ports: [{port: 80, targetPort: 80}]
YML

cat > $M/carrito.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: carrito, namespace: tienda}
spec:
  replicas: 2
  selector: {matchLabels: {app: carrito}}
  template:
    metadata: {labels: {app: carrito}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "$(web carrito 8080)"]
        ports: [{containerPort: 8080}]
        readinessProbe:
          httpGet: {path: /healthz, port: 8080}
          periodSeconds: 3
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: carrito, namespace: tienda}
spec:
  selector: {app: carrito}
  ports: [{port: 80, targetPort: 8080}]
YML

cat > $M/usuarios.yaml <<YML
apiVersion: apps/v1
kind: Deployment
metadata: {name: usuarios, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: usuarios}}
  template:
    metadata: {labels: {app: usuarios}}
    spec:
      containers:
      - name: web
        image: busybox:1.36
        command: ["sh", "-c", "$(web usuarios 9000)"]
        ports: [{name: web, containerPort: 9000}]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
---
apiVersion: v1
kind: Service
metadata: {name: usuarios, namespace: tienda}
spec:
  selector: {app: usuarios}
  ports: [{port: 80, targetPort: http}]
YML

cat > $M/cliente.yaml <<'YML'
apiVersion: apps/v1
kind: Deployment
metadata: {name: cliente, namespace: tienda}
spec:
  replicas: 1
  selector: {matchLabels: {app: cliente}}
  template:
    metadata: {labels: {app: cliente}}
    spec:
      containers:
      - name: cliente
        image: busybox:1.36
        command: ["sh", "-c", "exec sleep infinity"]
        resources: {requests: {cpu: 10m, memory: 8Mi}, limits: {memory: 32Mi}}
YML
kubectl apply -f $M/
for d in catalogo pagos usuarios cliente; do kubectl -n tienda rollout status deploy/$d --timeout=180s; done
chown -R analista:analista $M

cat > /usr/local/bin/probar-servicios <<'SH'
#!/usr/bin/env bash
# probar-servicios — pide http://<servicio>/ desde el pod cliente.
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for s in catalogo pagos carrito usuarios; do
  r=$(kubectl -n tienda exec deploy/cliente -- wget -q -T 3 -O - "http://$s/" 2>&1 | head -1)
  printf '  %-9s -> %s\n' "$s" "${r:-sin respuesta}"
done
SH
chmod 755 /usr/local/bin/probar-servicios

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Services sin tráfico (namespace tienda)

Los pods están "Running", pero sus Services no responden. Desde el pod
cliente, ninguno de estos funciona:

  probar-servicios      # http://catalogo/ http://pagos/ http://carrito/ http://usuarios/

Cada uno falla por una causa distinta. Encuéntralas y arréglalas en
~/manifiestos/ (y aplícalas). Cada servicio debe responder "<nombre> ok".

Reglas:
  - no quites la readinessProbe de carrito (está para algo);
  - los Services siguen en el puerto 80;
  - todas las réplicas deben recibir tráfico.

Por dónde empezar:
  kubectl -n tienda get endpointslices
  kubectl -n tienda describe svc catalogo
  kubectl -n tienda get pods --show-labels -o wide

Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 192 plantado."
