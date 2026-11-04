# Solución — Imagen de 1.2 GB con CVEs

## Qué pasaba

- `FROM golang:1.22.5-bookworm` en la imagen final: Debian completo + el
  compilador de Go (~800 MB) y cientos de paquetes con CVEs.
- `COPY . .` sin `.dockerignore`: un volcado de producción de 300 MB, un
  repo viejo y el `.env` con la contraseña acabaron en una capa.
- Sin `USER`: la API corría como root.

## Arreglo

```bash
cd ~/api
docker images tienda/api
trivy image tienda/api:1.0 > ~/trivy-antes.txt

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

docker build -t tienda/api:2.0 .
docker images tienda/api                 # ~1.2 GB -> ~8 MB
docker rm -f api
docker run -d --name api --restart unless-stopped -p 8080:8080 tienda/api:2.0
curl -s 'localhost:8080/api/precio?sku=7'       # "uid":65532

trivy image --severity HIGH,CRITICAL tienda/api:2.0 > ~/trivy-despues.txt
syft tienda/api:2.0 -o spdx-json > ~/sbom-api-2.0.json
bash /opt/lab/check.sh
```

## Lo que trivy sigue viendo

En la 2.0 ya no hay paquetes del sistema vulnerables, pero trivy puede
listar CVEs de la **librería estándar de Go 1.22.5** dentro del binario
(tipo `gobinary`). Eso no se arregla cambiando la base: se arregla
compilando con un Go parcheado (subir la imagen de la etapa `build`).
Una imagen mínima reduce la superficie; no sustituye a actualizar.

## Más allá del lab

- El `.env` estuvo en una capa de la 1.0: **rota la contraseña**. Borrarlo
  en una capa posterior no lo saca del historial de la imagen.
- Fija las bases por digest (`FROM golang@sha256:...`) y deja que
  Renovate/Dependabot proponga las subidas.
- Sube el SBOM junto a la imagen (`cosign attach sbom` o atestación) para
  responder en minutos a "¿estamos afectados por el CVE X?".
