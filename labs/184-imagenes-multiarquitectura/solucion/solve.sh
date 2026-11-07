#!/usr/bin/env bash
# Solución automática (corre como analista).
set -e
cd ~/hola
cat > Dockerfile <<'DF'
# Etapa de compilación en la plataforma de construcción (nativa, sin QEMU);
# Go compila en cruzado para la plataforma destino.
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS TARGETARCH
ARG VERSION=dev
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o /hola .

# Imagen final vacía: sólo el binario. No hay RUN, así que tampoco hace falta emular.
FROM scratch
COPY --from=build /hola /hola
ENTRYPOINT ["/hola"]
DF
docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.0 \
  -t localhost:5000/hola:1.0 --push .
docker buildx imagetools inspect localhost:5000/hola:1.0
docker run --rm --pull always localhost:5000/hola:1.0
echo "solve.sh completado."
