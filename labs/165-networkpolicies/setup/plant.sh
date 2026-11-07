#!/usr/bin/env bash
# Lab 165: red plana. Cualquier pod de cualquier namespace llega a la base de datos.
# El alumno aplica "negar por defecto" en tienda y abre sólo los flujos necesarios:
#   frontend -> api:8080 · api -> db:5432 · namespace monitoring -> api:8080
# (k3s aplica NetworkPolicies con su controlador embebido de kube-router.)
set -e
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
for _ in $(seq 1 300); do kubectl get node nodo1 2>/dev/null | grep -qw Ready && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=300s
for _ in $(seq 1 120); do kubectl -n default get sa default >/dev/null 2>&1 && break; sleep 2; done
kubectl -n kube-system rollout status deploy/coredns --timeout=300s

for ns in tienda monitoring externo; do
  kubectl create namespace $ns
  for _ in $(seq 1 60); do kubectl -n $ns get sa default >/dev/null 2>&1 && break; sleep 1; done
done

svc(){ # svc <ns> <nombre> <puerto>
cat <<YML
---
apiVersion: apps/v1
kind: Deployment
metadata: {name: $2, namespace: $1}
spec:
  replicas: 1
  selector: {matchLabels: {app: $2}}
  template:
    metadata: {labels: {app: $2}}
    spec:
      containers:
      - name: $2
        image: busybox:1.36
        command: ["sh", "-c", "mkdir -p /www && echo '$2 ok' > /www/index.html && exec httpd -f -p $3 -h /www"]
        ports: [{containerPort: $3}]
        resources:
          requests: {cpu: 10m, memory: 8Mi}
          limits:   {memory: 32Mi}
---
apiVersion: v1
kind: Service
metadata: {name: $2, namespace: $1}
spec:
  selector: {app: $2}
  ports: [{port: $3, targetPort: $3}]
YML
}
mkdir -p /home/analista/manifiestos /home/analista/politicas
{ svc tienda frontend 8080; svc tienda api 8080; svc tienda db 5432
  svc monitoring prometheus 9090; svc externo atacante 8080; } > /home/analista/manifiestos/cargas.yaml
kubectl apply -f /home/analista/manifiestos/cargas.yaml
for d in frontend api db; do kubectl -n tienda rollout status deploy/$d --timeout=180s; done
kubectl -n monitoring rollout status deploy/prometheus --timeout=180s
kubectl -n externo rollout status deploy/atacante --timeout=180s

cat > /usr/local/bin/probar-red <<'SH'
#!/usr/bin/env bash
# probar-red — matriz de conectividad: quién llega a quién (wget con 3 s de espera).
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
p(){ # p <ns-origen> <deploy-origen> <url> <esperado>
  if kubectl -n "$1" exec deploy/"$2" -- wget -q -T 3 -O /dev/null "$3" 2>/dev/null; then r=PERMITIDO; else r=BLOQUEADO; fi
  m=$([ "$r" = "$4" ] && echo "ok " || echo "MAL")
  printf '  [%s] %-22s -> %-42s %s (debe: %s)\n' "$m" "$1/$2" "$3" "$r" "$4"
}
p tienda frontend   http://api.tienda:8080 PERMITIDO
p tienda api        http://db.tienda:5432  PERMITIDO
p monitoring prometheus http://api.tienda:8080 PERMITIDO
p tienda frontend   http://db.tienda:5432  BLOQUEADO
p monitoring prometheus http://db.tienda:5432 BLOQUEADO
p externo atacante  http://api.tienda:8080 BLOQUEADO
p externo atacante  http://db.tienda:5432  BLOQUEADO
p externo atacante  http://frontend.tienda:8080 BLOQUEADO
SH
chmod 0755 /usr/local/bin/probar-red
chown -R analista:analista /home/analista/manifiestos /home/analista/politicas

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · NetworkPolicies (namespace tienda)

La auditoría encontró que desde cualquier pod del clúster (incluido el
namespace "externo") se llega a la base de datos. Hoy la red es plana.

Flujos que SÍ deben existir:
  tienda/frontend          -> tienda/api:8080
  tienda/api               -> tienda/db:5432
  namespace monitoring     -> tienda/api:8080   (scraping de métricas)
Todo lo demás hacia tienda: bloqueado.

1. Política "default-deny" en tienda: niega todo el tráfico de ENTRADA a
   todos los pods del namespace.
2. Políticas que permitan sólo los tres flujos de arriba (por etiqueta de pod
   y, para monitoring, por namespaceSelector).
3. Guarda tus políticas en ~/politicas/ y aplícalas.

Matriz de conectividad en cualquier momento:  probar-red
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 165 plantado."
