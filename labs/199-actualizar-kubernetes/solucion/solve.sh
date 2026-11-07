#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
# 1. APIs eliminadas en v1.32: flowcontrol v1beta3 -> v1 (mismo esquema).
grep -rl 'flowcontrol.apiserver.k8s.io/v1beta3' ~/manifiestos | while read -r f; do
  sed -i 's#flowcontrol.apiserver.k8s.io/v1beta3#flowcontrol.apiserver.k8s.io/v1#' "$f"
done
kubectl apply -f ~/manifiestos/

# 2. Copia consistente del estado (SQLite en uso: API de backup, no cp).
sudo mkdir -p /var/backups/k3s
F=/var/backups/k3s/state-$(date +%Y%m%d-%H%M%S).db
sudo python3 - "$F" <<'PY'
import sqlite3, sys
src = sqlite3.connect("file:/var/lib/rancher/k3s/server/db/state.db?mode=ro", uri=True)
dst = sqlite3.connect(sys.argv[1])
src.backup(dst)
dst.close()
print("copia:", sys.argv[1], dst and "ok")
PY
sudo cp /var/lib/rancher/k3s/server/token /var/backups/k3s/token
sleep 1

# 3. Verificar el binario y sustituirlo.
cd /opt/k3s/v1.32.0
grep ' k3s$' sha256sum-amd64.txt | sha256sum -c -
sudo install -m 0755 /opt/k3s/v1.32.0/k3s /usr/local/bin/k3s
sudo systemctl restart k3s

# 4. Esperar y comprobar.
for _ in $(seq 1 90); do kubectl get node nodo1 2>/dev/null | grep -q 'v1.32.0' && break; sleep 2; done
kubectl wait --for=condition=Ready node/nodo1 --timeout=180s
kubectl -n kube-system rollout status deploy/coredns --timeout=180s
kubectl -n tienda rollout status deploy/tienda --timeout=180s
kubectl get node -o wide
kubectl diff -f ~/manifiestos/ && echo "manifiestos al día"
echo "solve.sh completado."
