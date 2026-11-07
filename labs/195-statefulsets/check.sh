#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
K="kubectl -n tienda"
pide(){ $K exec deploy/cliente -- wget -q -T 3 -O - "http://db-$1.db.tienda.svc.cluster.local:8080/" 2>/dev/null; }

echo "== Lab 195 · StatefulSets — comprobación =="

SN=$($K get statefulset db -o jsonpath='{.spec.serviceName}' 2>/dev/null)
R=$($K get statefulset db -o jsonpath='{.spec.replicas}' 2>/dev/null)
VT=$($K get statefulset db -o jsonpath='{.spec.volumeClaimTemplates[*].metadata.name}' 2>/dev/null)
CIP=$($K get svc db -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
if [ "$SN" = db ] && [ "$R" = 3 ] && [ -n "$VT" ] && [ "$CIP" = None ]; then
  ok "StatefulSet db: 3 réplicas, serviceName db (headless) y volumeClaimTemplates ($VT)."
else
  no "Esperaba StatefulSet db (replicas 3, serviceName db, volumeClaimTemplates) y Service db con clusterIP: None. Hay: serviceName='$SN' replicas='$R' plantillas='$VT' clusterIP='$CIP'."
fi
$K rollout status statefulset/db --timeout=180s >/dev/null 2>&1

BIEN=1; MAL=""
for i in 0 1 2; do
  r=$(pide $i)
  [ "$r" = "nodo=db-$i datos=db-$i" ] || { BIEN=0; MAL="$MAL db-$i='${r:-nada}'"; }
done
[ $BIEN = 1 ] && ok "db-0, db-1 y db-2 responden por su nombre estable, cada uno con sus datos." \
              || no "Nombres estables o datos propios:$MAL."

PV=""
for i in 0 1 2; do
  c=$($K get pod db-$i -o jsonpath='{.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null)
  ph=$($K get pvc "$c" -o jsonpath='{.status.phase}' 2>/dev/null)
  [ "$ph" = Bound ] && PV="$PV $c"
done
if [ "$(echo $PV | wc -w)" = 3 ] && [ "$(echo $PV | tr ' ' '\n' | sort -u | wc -l)" = 3 ]; then
  ok "Cada réplica tiene su propio PVC:$PV."
else
  no "Las réplicas no tienen tres PVC propios y Bound (tienen:${PV:- ninguno})."
fi

# Persistencia: marca en db-1, se borra el pod, debe volver con el mismo nombre y la marca.
M=marca-$RANDOM$RANDOM
if $K exec db-1 -- sh -c "echo $M > /data/marca" >/dev/null 2>&1; then
  UID1=$($K get pod db-1 -o jsonpath='{.metadata.uid}')
  $K delete pod db-1 --wait=false >/dev/null 2>&1
  for _ in $(seq 1 60); do
    u=$($K get pod db-1 -o jsonpath='{.metadata.uid}' 2>/dev/null)
    if [ -n "$u" ] && [ "$u" != "$UID1" ] && $K wait --for=condition=Ready pod/db-1 --timeout=5s >/dev/null 2>&1; then break; fi
    sleep 2
  done
  V=$($K exec db-1 -- cat /data/marca 2>/dev/null)
  if [ "$V" = "$M" ] && [ "$(pide 1)" = "nodo=db-1 datos=db-1" ]; then
    ok "Borrado db-1, vuelve como db-1 con sus datos (/data/marca intacto)."
  else
    no "Tras borrar db-1 no vuelve con el mismo nombre y los mismos datos."
  fi
else
  no "No se puede escribir /data/marca en db-1 (¿existe el pod? ¿monta /data?)."
fi

if ! $K get deploy db >/dev/null 2>&1 && ! $K get pvc datos-compartidos >/dev/null 2>&1; then
  ok "Sin restos: ni Deployment db ni PVC datos-compartidos."
else
  no "Quedan el Deployment db o el PVC datos-compartidos."
fi

kubectl diff -f /home/analista/manifiestos/db.yaml >/dev/null 2>&1; D=$?
if [ $D -eq 0 ] && grep -q 'kind: StatefulSet' /home/analista/manifiestos/db.yaml; then
  ok "~/manifiestos/db.yaml describe lo que corre."
else
  no "~/manifiestos/db.yaml no coincide con el clúster (kubectl diff) o no contiene el StatefulSet."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Identidad estable, volumen propio y orden: eso es un StatefulSet."; exit 0; } || exit 1
