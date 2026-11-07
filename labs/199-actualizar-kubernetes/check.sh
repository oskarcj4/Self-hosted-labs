#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
M=/home/analista/manifiestos

echo "== Lab 199 · Actualizar Kubernetes — comprobación =="

# 1) Manifiestos sin APIs eliminadas en v1.32
if grep -rqE 'flowcontrol\.apiserver\.k8s\.io/v1beta[123]' $M 2>/dev/null; then
  no "~/manifiestos aún usa flowcontrol.apiserver.k8s.io/v1beta3 (eliminada en v1.32)."
else
  ok "~/manifiestos ya no usa APIs eliminadas en v1.32."
fi

# 2) Binario y versión
ESP=$(awk '$2=="k3s"{print $1}' /opt/k3s/v1.32.0/sha256sum-amd64.txt 2>/dev/null)
TEN=$(sha256sum /usr/local/bin/k3s 2>/dev/null | awk '{print $1}')
KV=$(kubectl get node nodo1 -o jsonpath='{.status.nodeInfo.kubeletVersion}' 2>/dev/null)
SV=$(kubectl version -o json 2>/dev/null | python3 -c 'import json,sys;print(json.load(sys.stdin)["serverVersion"]["gitVersion"])' 2>/dev/null)
if [ -n "$ESP" ] && [ "$TEN" = "$ESP" ] && [ "$KV" = v1.32.0+k3s1 ] && [ "$SV" = v1.32.0+k3s1 ]; then
  ok "El clúster corre v1.32.0+k3s1 con el binario verificado por sha256."
else
  no "Versión: nodo '${KV:-?}', API server '${SV:-?}'; sha256 del binario $( [ "$TEN" = "$ESP" ] && echo coincide || echo 'NO coincide') con la lista oficial."
fi

# 3) Copia de seguridad hecha ANTES del arranque con la versión nueva
INI=$(systemctl show -p ExecMainStartTimestamp --value k3s 2>/dev/null)
INI_S=$(date -d "$INI" +%s 2>/dev/null || echo 0)
PLA_S=$(stat -c %Y /opt/lab/.planted 2>/dev/null || echo 0)
BK=""
for f in $(ls -t /var/backups/k3s/* 2>/dev/null); do
  [ -f "$f" ] || continue
  t=$(stat -c %Y "$f")
  [ "$t" -gt "$PLA_S" ] && [ "$t" -lt "$INI_S" ] || continue
  if python3 - "$f" <<'PY' 2>/dev/null; then BK=$f; break; fi
import sqlite3, sys
c = sqlite3.connect(f"file:{sys.argv[1]}?mode=ro", uri=True)
assert c.execute("pragma integrity_check").fetchone()[0] == "ok"
n = c.execute("select count(*) from kine where name like '/registry/deployments/tienda/%'").fetchone()[0]
assert n >= 1
PY
done
if [ -n "$BK" ]; then
  ok "Copia de seguridad válida anterior a la actualización: $BK."
else
  no "No hay en /var/backups/k3s/ una copia SQLite íntegra (con la tienda dentro) hecha antes de arrancar la versión nueva."
fi

# 4) Después: la tienda sirve, el sistema está sano y los manifiestos se aplican
IP=$(kubectl -n tienda get svc tienda -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
RD=$(kubectl -n tienda get deploy tienda -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
CD=$(kubectl -n kube-system get deploy coredns -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$RD" = 2 ] && [ "${CD:-0}" -ge 1 ] && curl -s --max-time 3 "http://$IP/" | grep -qi nginx; then
  ok "Tras la actualización: tienda 2/2 sirviendo y CoreDNS listo."
else
  no "Tras la actualización algo no está sano: tienda listos='${RD:-0}', coredns='${CD:-0}'."
fi
ERR=""
for f in $M/*.yaml; do
  kubectl diff -f "$f" >/dev/null 2>/tmp/.diff199; r=$?
  [ $r -gt 1 ] && ERR="$ERR $(basename "$f"): $(head -1 /tmp/.diff199)"
  [ $r -eq 1 ] && ERR="$ERR $(basename "$f"): no aplicado"
done
FS=$(kubectl get flowschemas.v1.flowcontrol.apiserver.k8s.io ci-lotes -o jsonpath='{.spec.priorityLevelConfiguration.name}' 2>/dev/null)
if [ -z "$ERR" ] && [ "$FS" = ci-lotes ]; then
  ok "Los manifiestos se aplican contra v1.32 y la FlowSchema ci-lotes sigue en vigor."
else
  no "Manifiestos contra v1.32:${ERR:- ok}; FlowSchema ci-lotes='${FS:-no existe}'."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 APIs migradas, copia hecha, binario verificado: actualización sin sustos."; exit 0; } || exit 1
