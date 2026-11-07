# Solución — Imágenes multiarquitectura

## Dockerfile

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS TARGETARCH
ARG VERSION=dev
WORKDIR /src
COPY go.mod ./
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -ldflags "-s -w -X main.version=$VERSION" -o /hola .

FROM scratch
COPY --from=build /hola /hola
ENTRYPOINT ["/hola"]
```

```bash
docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.0 \
  -t localhost:5000/hola:1.0 --push .
```

## Qué pasaba

| | Etapa `build` corre en | `go build` compila para | Variante arm64 contiene |
|-|------------------------|--------------------------|-------------------------|
| Original | amd64 (`$BUILDPLATFORM`) | amd64 (no se le dice otra cosa) | binario **amd64** |
| Arreglado | amd64 | `$TARGETARCH` | binario arm64 |

## Por qué

- Un índice (manifest list) guarda un manifiesto por plataforma. El cliente
  elige el suyo al hacer `pull`.
- La imagen multiplataforma necesita el almacén de imágenes de containerd o un
  builder `docker-container`. El lab activa el primero en el dockerd interno.

## Más allá del lab

- Atestaciones: buildx añade proveniencia (la plataforma `unknown/unknown` del índice). Lab 218 (SBOM) y 219 (firmas).
- Python, Node y Java: el código es portable, pero las dependencias nativas (wheels) necesitan la variante de cada arquitectura.
- En CI: `docker/setup-buildx-action` y `platforms: linux/amd64,linux/arm64`.
