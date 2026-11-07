#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/manifiestos
# 1. El Issuer ca-tienda vive en cert-manager: desde tienda no se ve. Un
#    ClusterIssuer sí, y lee su secret del namespace de cert-manager.
python3 - <<'PY'
p = "01-ca.yaml"
s = open(p).read()
s = s.replace("""kind: Issuer
metadata: {name: ca-tienda, namespace: cert-manager}""", """kind: ClusterIssuer
metadata: {name: ca-tienda}""")
open(p, "w").write(s)
PY
kubectl -n cert-manager delete issuer ca-tienda --ignore-not-found
# 2. El certificado: emisor ClusterIssuer y los nombres con los que se accede.
sed -i \
  -e 's/issuerRef: {name: ca-tienda, kind: Issuer, group: cert-manager.io}/issuerRef: {name: ca-tienda, kind: ClusterIssuer, group: cert-manager.io}/' \
  -e 's/dnsNames: \[www.tienda.local\]/dnsNames: [tienda.local, www.tienda.local, tienda.tienda.svc.cluster.local]/' \
  02-certificado.yaml
# 3. El pod montaba un secret que no existe: el del Certificate es web-tls.
sed -i 's/secret: {secretName: tienda-tls}/secret: {secretName: web-tls}/' 03-web.yaml
kubectl apply -f 01-ca.yaml -f 02-certificado.yaml -f 03-web.yaml
kubectl -n tienda wait --for=condition=Ready certificate/web --timeout=120s
kubectl -n tienda rollout status deploy/tienda --timeout=120s
probar-tls tienda.local
probar-tls tienda.tienda.svc.cluster.local
echo "solve.sh completado."
