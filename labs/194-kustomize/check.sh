#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
A=/home/analista/app
T=$(mktemp -d)

echo "== Lab 194 · Kustomize — comprobación =="

if [ -f $A/base/kustomization.yaml ] && [ -f $A/overlays/dev/kustomization.yaml ] && [ -f $A/overlays/prod/kustomization.yaml ] \
   && grep -q '\.\./\.\./base' $A/overlays/dev/kustomization.yaml && grep -q '\.\./\.\./base' $A/overlays/prod/kustomization.yaml; then
  ok "Estructura base/ + overlays/{dev,prod} que heredan de ../../base."
else
  no "Falta ~/app/base/kustomization.yaml u overlays/{dev,prod}/kustomization.yaml apuntando a ../../base."
fi

# Renderiza cada overlay a JSON (dry-run de cliente: no toca el clúster).
REN=1
for e in dev prod; do
  kubectl kustomize $A/overlays/$e > $T/$e.yaml 2>$T/$e.err \
    && kubectl apply --dry-run=client -o json -f $T/$e.yaml > $T/$e.json 2>>$T/$e.err || { REN=0; echo "     $e: $(head -2 $T/$e.err)"; }
done

if [ $REN = 1 ]; then
  python3 - "$T" > $T/analisis 2>&1 <<'PY'
import json, re, sys
T = sys.argv[1]
esp = {"dev": (1, "64Mi", "debug"), "prod": (3, "128Mi", "info")}
for e, (rep, mem, lvl) in esp.items():
    d = json.load(open(f"{T}/{e}.json"))
    items = d["items"] if d.get("kind") == "List" else [d]
    por = {}
    for i in items:
        por.setdefault(i["kind"], []).append(i)
    malo = []
    deps = por.get("Deployment", []); cms = por.get("ConfigMap", []); svcs = por.get("Service", [])
    if len(deps) != 1 or len(svcs) != 1:
        print(f"{e}|0|esperaba 1 Deployment y 1 Service, hay {len(deps)} y {len(svcs)}"); continue
    dp = deps[0]; sp = dp["spec"]; pod = sp["template"]; c = pod["spec"]["containers"][0]
    for i in items:
        if i["metadata"].get("namespace") != e: malo.append(f"{i['kind']} fuera del namespace {e}")
    if sp.get("replicas") != rep: malo.append(f"réplicas {sp.get('replicas')} (esperaba {rep})")
    if c.get("resources", {}).get("limits", {}).get("memory") != mem:
        malo.append(f"límite de memoria {c.get('resources',{}).get('limits',{}).get('memory')} (esperaba {mem})")
    if "readinessProbe" not in c: malo.append("sin readinessProbe")
    if pod["metadata"].get("labels", {}).get("entorno") != e: malo.append(f"pods sin etiqueta entorno: {e}")
    if c.get("image") != "nginx:1.27-alpine": malo.append(f"imagen {c.get('image')}")
    gen = [m for m in cms if re.fullmatch(r"web-config-[a-z0-9]{10}", m["metadata"]["name"])]
    if len(gen) != 1:
        malo.append("la ConfigMap no la genera configMapGenerator (falta el sufijo hash)")
    else:
        cm = gen[0]; n = cm["metadata"]["name"]; dat = cm.get("data", {})
        if dat.get("LOG_LEVEL") != lvl: malo.append(f"LOG_LEVEL={dat.get('LOG_LEVEL')} (esperaba {lvl})")
        if dat.get("index.html", "").strip() != f"web entorno={e}": malo.append(f"index.html={dat.get('index.html','').strip()!r}")
        refs = [v["configMap"]["name"] for v in pod["spec"].get("volumes", []) if "configMap" in v]
        refs += [x["valueFrom"]["configMapKeyRef"]["name"] for x in c.get("env", []) if "configMapKeyRef" in x.get("valueFrom", {})]
        if not refs or any(r != n for r in refs): malo.append(f"el Deployment no referencia {n} (referencia {refs})")
    print(f"{e}|{0 if malo else 1}|{'; '.join(malo) or 'ok'}")
PY
  for e in dev prod; do
    L=$(grep "^$e|" $T/analisis); [ -z "$L" ] && L="$e|0|$(tail -1 $T/analisis)"
    if [ "$(echo "$L" | cut -d'|' -f2)" = 1 ]; then
      ok "overlays/$e genera lo esperado (namespace, réplicas, memoria, probe, config con hash)."
    else
      no "overlays/$e: $(echo "$L" | cut -d'|' -f3-)"
    fi
  done
else
  no "kubectl kustomize falla en algún overlay."
  no "(no se puede analizar lo generado)"
fi

if [ -d $A/overlays ] && ! grep -rqE '^\s*image:|kind: *Service\b' $A/overlays 2>/dev/null; then
  ok "La imagen y el Service sólo se declaran en la base."
else
  no "Los overlays repiten la imagen o el Service: deben vivir sólo en la base."
fi
if [ ! -e $A/dev ] && [ ! -e $A/prod ]; then
  ok "Ya no quedan las copias ~/app/dev y ~/app/prod."
else
  no "Siguen existiendo ~/app/dev o ~/app/prod: una sola fuente de verdad."
fi

# Aplicado y sirviendo
APL=1
for e in dev prod; do
  kubectl diff -k $A/overlays/$e >/dev/null 2>&1; [ $? -eq 0 ] || APL=0
  IP=$(kubectl -n $e get svc web -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  R=$(curl -s --max-time 3 http://$IP/ 2>/dev/null)
  RD=$(kubectl -n $e get deploy web -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
  W=$(kubectl -n $e get deploy web -o jsonpath='{.spec.replicas}' 2>/dev/null)
  [ "$R" = "web entorno=$e" ] && [ -n "$RD" ] && [ "$RD" = "$W" ] || APL=0
done
[ $APL = 1 ] && ok "Los dos entornos aplicados con apply -k, listos y sirviendo su página." \
             || no "Algún entorno no está aplicado (kubectl diff -k), no está listo o no sirve 'web entorno=<e>' (probar-web)."
rm -rf $T

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Una base, dos overlays y ninguna copia que se desvíe."; exit 0; } || exit 1
