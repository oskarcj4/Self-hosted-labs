#!/usr/bin/env bash
# Al pasar, deja la marca de "resuelto": la plataforma destruye el lab poco después.
trap '[ $? -eq 0 ] && { touch /tmp/.tclab-solved 2>/dev/null; echo "⏳ Lab resuelto: se autodestruirá en ~1 minuto."; }' EXIT
# Validador del Lab 142.
pass=0; fail=0
ok(){ echo "  [✓] $1"; pass=$((pass+1)); }
no(){ echo "  [✗] $1"; fail=$((fail+1)); }
. /etc/profile.d/trivy.sh
SUDO=""; [ "$(id -u)" -eq 0 ] || SUDO="sudo -n"
H=/home/analista
P=$H/api
IMG=tienda/api:2.0

echo "== Lab 142 · Imagen de 1.2 GB con CVEs — comprobación =="

grep -qE 'tienda/api:1\.0' $H/trivy-antes.txt 2>/dev/null && grep -qE 'Total: [0-9]+' $H/trivy-antes.txt \
  && ok "trivy-antes.txt: informe de trivy de la 1.0." || no "~/trivy-antes.txt debe ser la salida de 'trivy image tienda/api:1.0'."

nfrom=$(grep -ciE '^\s*FROM\s' $P/Dockerfile 2>/dev/null)
ultimo=$(grep -iE '^\s*FROM\s' $P/Dockerfile 2>/dev/null | tail -1)
[ "${nfrom:-0}" -ge 2 ] && grep -qiE 'COPY\s+--from=' $P/Dockerfile \
  && ok "Dockerfile multi-stage ($nfrom etapas, COPY --from)." || no "El Dockerfile no es multi-stage (2+ FROM y COPY --from)."
echo "$ultimo" | grep -qE 'distroless/static-debian12|^\s*FROM\s+scratch' \
  && ok "La etapa final es distroless/scratch." || no "La etapa final no es distroless: $ultimo"
if [ -f $P/.dockerignore ] && grep -qE '^/?testdata' $P/.dockerignore && grep -qE '^/?\.env' $P/.dockerignore; then
  ok ".dockerignore excluye testdata/ y .env."
else no ".dockerignore debe excluir al menos testdata/ y .env."; fi

if docker image inspect $IMG >/dev/null 2>&1; then
  mb=$(( $(docker image inspect -f '{{.Size}}' $IMG) / 1000000 ))
  [ "$mb" -lt 50 ] && ok "tienda/api:2.0 pesa ${mb} MB." || no "tienda/api:2.0 pesa ${mb} MB (objetivo < 50 MB)."
  u=$(docker image inspect -f '{{.Config.User}}' $IMG)
  case "$u" in ""|root|0|0:0|root:root) no "La imagen corre como root (USER='${u}').";; *) ok "La imagen corre como usuario no root ($u).";; esac
  docker run --rm --entrypoint /bin/sh $IMG -c true >/dev/null 2>&1 \
    && no "La imagen final tiene shell (/bin/sh): no es distroless." || ok "Sin shell en la imagen final."
  # Como root: la caché de trivy puede ser de otro usuario.
  hits=$($SUDO env $(grep -o 'TRIVY_[A-Z_]*=[^ ]*' /etc/profile.d/trivy.sh) trivy image --quiet --pkg-types os --severity HIGH,CRITICAL --format json $IMG 2>/dev/null \
         | jq '[.Results[]?.Vulnerabilities // [] | length] | add // 0')
  [ "${hits:-x}" = 0 ] && ok "trivy: 0 CVEs HIGH/CRITICAL en paquetes del sistema de la 2.0." \
    || no "trivy: la 2.0 tiene ${hits:-?} CVEs HIGH/CRITICAL en paquetes del sistema."
  docker rm -f tclab-probe >/dev/null 2>&1; docker create --name tclab-probe $IMG >/dev/null 2>&1
  fuga=""; for f in /src/.env /src/testdata /src/main.go /root/.cache/go-build; do
    docker cp tclab-probe:$f - >/dev/null 2>&1 && fuga="$fuga $f"
  done; docker rm -f tclab-probe >/dev/null 2>&1
  [ -z "$fuga" ] && ok "Ni código, ni .env, ni volcado, ni caché de Go dentro de la 2.0." || no "La imagen 2.0 contiene:$fuga"
else
  no "No existe la imagen tienda/api:2.0."
fi

c=$(docker ps -q --filter name='^api$')
img=$(docker inspect -f '{{.Config.Image}}' api 2>/dev/null)
[ -n "$c" ] && [ "$img" = "$IMG" ] && ok "El contenedor 'api' corre la 2.0." || no "El contenedor 'api' no corre tienda/api:2.0 (corre: ${img:-nada})."
curl -fs --max-time 3 'http://127.0.0.1:8080/api/precio?sku=7' | jq -e '.uid != 0' >/dev/null 2>&1 \
  && ok "La API responde en :8080 con un UID distinto de 0." || no "La API no responde en :8080 o corre con UID 0."

grep -qE 'tienda/api:2\.0' $H/trivy-despues.txt 2>/dev/null && ok "trivy-despues.txt: informe de la 2.0." \
  || no "~/trivy-despues.txt debe ser la salida de trivy sobre tienda/api:2.0."
S=$H/sbom-api-2.0.json
if jq -e '.spdxVersion // .bomFormat' $S >/dev/null 2>&1; then
  jq -r '.. | strings' $S 2>/dev/null | grep -q 'tienda/api' \
    && ok "SBOM en JSON ($(jq -r '.spdxVersion // .bomFormat' $S)) que describe tienda/api." \
    || no "El SBOM no menciona tienda/api: ¿es de otra imagen?"
else
  no "~/sbom-api-2.0.json no es un SBOM SPDX/CycloneDX en JSON."
fi

echo "---------------------------------------"
echo "Resultado: $pass superados, $fail pendientes."
[ "$fail" -eq 0 ] && { echo "🎉 Imagen mínima, sin root y con inventario."; exit 0; } || exit 1
