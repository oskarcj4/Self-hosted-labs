# Solución — Actualizar Kubernetes

```bash
# 1. APIs eliminadas en 1.32
sed -i 's#flowcontrol.apiserver.k8s.io/v1beta3#flowcontrol.apiserver.k8s.io/v1#' ~/manifiestos/prioridad-ci.yaml
kubectl apply -f ~/manifiestos/

# 2. Backup consistente (SQLite en uso) + token
sudo mkdir -p /var/backups/k3s
sudo python3 -c '
import sqlite3
s = sqlite3.connect("file:/var/lib/rancher/k3s/server/db/state.db?mode=ro", uri=True)
d = sqlite3.connect("/var/backups/k3s/state-antes-1.32.db"); s.backup(d)'
sudo cp /var/lib/rancher/k3s/server/token /var/backups/k3s/

# 3. Verificar e instalar
cd /opt/k3s/v1.32.0 && grep ' k3s$' sha256sum-amd64.txt | sha256sum -c -
sudo install -m 0755 k3s /usr/local/bin/k3s
sudo systemctl restart k3s

# 4. Verificar
kubectl get nodes                       # v1.32.0+k3s1
kubectl diff -f ~/manifiestos/
```

## Restaurar si sale mal

```bash
sudo systemctl stop k3s
sudo install -m 0755 <binario v1.31.4> /usr/local/bin/k3s
sudo cp /var/backups/k3s/state-antes-1.32.db /var/lib/rancher/k3s/server/db/state.db
sudo rm -f /var/lib/rancher/k3s/server/db/state.db-{wal,shm}
sudo systemctl start k3s
```

Volver a la versión anterior con el estado escrito por la nueva no está
soportado: por eso la copia va **antes**.

## Calendario de eliminaciones recientes

| Versión | API eliminada |
|---------|---------------|
| 1.25 | `policy/v1beta1` PodSecurityPolicy y PDB, `batch/v1beta1` CronJob |
| 1.26 | `autoscaling/v2beta2` HPA, `flowcontrol/v1beta1` |
| 1.29 | `flowcontrol/v1beta2` |
| 1.32 | `flowcontrol/v1beta3` |
