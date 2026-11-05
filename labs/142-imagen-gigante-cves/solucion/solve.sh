#!/usr/bin/env bash
# Solución automática (sirve para probar el lab). Corre como root dentro del lab.
set -e
. /etc/profile.d/trivy.sh
H=/home/analista
cd $H/api
docker images tienda/api
trivy image tienda/api:1.0 > $H/trivy-antes.txt
grep Total $H/trivy-antes.txt | head -3

cat > .dockerignore <<'I'
.git
.git-old
.env
testdata/
Dockerfile
.dockerignore
*.md
I
cat > Dockerfile <<'DF'
# Etapa 1: compilar (con todas las herramientas)
FROM golang:1.22.5-bookworm AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOTOOLCHAIN=local
COPY go.mod ./
RUN go mod download
COPY *.go ./
RUN go build -trimpath -ldflags="-s -w -X main.version=2.0" -o /out/api .

# Etapa 2: ejecutar (sólo el binario)
FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api"]
DF
docker build -q -t tienda/api:2.0 .
docker images tienda/api
docker rm -f api >/dev/null
docker run -d --name api --restart unless-stopped -p 8080:8080 tienda/api:2.0
sleep 2; curl -s 'localhost:8080/api/precio?sku=7'; echo
trivy image --severity HIGH,CRITICAL tienda/api:2.0 > $H/trivy-despues.txt
syft -q tienda/api:2.0 -o spdx-json > $H/sbom-api-2.0.json
chown -R analista:analista $H
