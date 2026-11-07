#!/usr/bin/env bash
[ "$(id -u)" -eq 0 ] || exec sudo -n bash "$0" "$@"
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
T=$(mktemp -d)
kubectl -n cert-manager get secret ca-tienda -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d > $T/ca.crt
IP=$(kubectl -n tienda get svc tienda -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
https(){ curl -s --max-time 5 --cacert $T/ca.crt --resolve "$1:443:$IP" "https://$1/" 2>/dev/null; }
serie(){ kubectl -n tienda get secret web-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d \
         | openssl x509 -noout -serial 2>/dev/null; }

echo "== Lab 193 · cert-manager — comprobación =="

R=$(kubectl -n tienda get certificate web -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
[ "$R" = True ] && ok "Certificate tienda/web en Ready." \
                || no "Certificate tienda/web no está Ready (kubectl -n tienda describe certificate web)."

CRT=$(kubectl -n tienda get secret web-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d)
if [ -n "$CRT" ] && echo "$CRT" | openssl verify -CAfile $T/ca.crt >/dev/null 2>&1; then
  ok "El certificado lo firma la CA interna."
else
  no "El secret web-tls no existe o su certificado no lo firma la CA interna (ca-tienda)."
fi
SAN=$(echo "$CRT" | openssl x509 -noout -ext subjectAltName 2>/dev/null | tr -d ' \n')
if echo "$SAN" | grep -q 'DNS:tienda.local' && echo "$SAN" | grep -q 'DNS:tienda.tienda.svc.cluster.local'; then
  ok "Nombres del certificado: ${SAN#*subjectAlternativeName:}."
else
  no "El certificado no cubre tienda.local y tienda.tienda.svc.cluster.local (tiene: ${SAN:-nada})."
fi

R1=$(https tienda.local); R2=$(https tienda.tienda.svc.cluster.local)
if [ "$R1" = "tienda ok" ] && [ "$R2" = "tienda ok" ]; then
  ok "HTTPS verificado con la CA interna en los dos nombres."
else
  no "HTTPS: tienda.local → '${R1:-error}', tienda.tienda.svc.cluster.local → '${R2:-error}' (pod: $(kubectl -n tienda get pods -l app=tienda --no-headers 2>/dev/null | awk '{print $3}' | head -1))."
fi

S1=$(serie)
if [ -n "$S1" ]; then
  kubectl -n tienda delete secret web-tls >/dev/null 2>&1
  S2=""; for _ in $(seq 1 30); do S2=$(serie); [ -n "$S2" ] && break; sleep 2; done
  if [ -n "$S2" ] && [ "$S2" != "$S1" ]; then
    ok "Borrado el secret, cert-manager emite uno nuevo solo ($S2)."
  else
    no "Tras borrar el secret web-tls, cert-manager no lo ha vuelto a emitir en 60 s."
  fi
  kubectl -n tienda rollout restart deploy/tienda >/dev/null 2>&1
  kubectl -n tienda rollout status deploy/tienda --timeout=90s >/dev/null 2>&1
else
  no "No hay secret web-tls que renovar."
fi

DIF=""
for f in /home/analista/manifiestos/*.yaml; do
  kubectl diff -f "$f" >/dev/null 2>&1; [ $? -eq 1 ] && DIF="$DIF $(basename "$f")"
done
[ -z "$DIF" ] && ok "Lo que corre coincide con ~/manifiestos." || no "El clúster no coincide con ~/manifiestos (kubectl diff):$DIF."
rm -rf $T

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Certificados emitidos y renovados solos, por tu propia CA."; exit 0; } || exit 1
