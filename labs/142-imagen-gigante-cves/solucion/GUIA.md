# Resolución guiada · Lab 142

:::piensa Antes de tocar nada
Una imagen grande no es sólo lenta: cada paquete que no usas es un CVE que
tienes que justificar, y cada fichero que copias por accidente puede ser un
secreto. Mide primero: tamaño, capas, CVEs y qué hay dentro.
:::

## Paso 1 · ¿De dónde salen los 1.2 GB?

:::pista Cómo comprobarlo
```bash
docker images tienda/api
docker history --no-trunc tienda/api:1.0 | head
docker run --rm --entrypoint ls tienda/api:1.0 -la /src /src/testdata
```
La base golang (~800 MB) y `COPY . .` (300 MB de volcado + repo viejo + `.env`).
:::

## Paso 2 · ¿Cuántos CVEs y de dónde?

:::pista Cómo comprobarlo
```bash
trivy image tienda/api:1.0 > ~/trivy-antes.txt
grep -E '^(tienda|usr|Total)' ~/trivy-antes.txt | head
```
Casi todos vienen de paquetes de Debian que la API no usa.
:::

## Paso 3 · Multi-stage

**Pregúntate:** ¿qué necesita la API para **ejecutarse**? ¿Y para **compilarse**?

:::pista Cómo hacerlo
Para ejecutarse, sólo el binario (estático con `CGO_ENABLED=0`).
```dockerfile
FROM golang:1.22.5-bookworm AS build
WORKDIR /src
ENV CGO_ENABLED=0 GOTOOLCHAIN=local
COPY go.mod ./
RUN go mod download
COPY *.go ./
RUN go build -trimpath -ldflags="-s -w" -o /out/api .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api /api
USER nonroot:nonroot
ENTRYPOINT ["/api"]
```
Copiar `go.mod` antes que el código aprovecha la caché de capas.
:::

## Paso 4 · .dockerignore

:::pista Cómo hacerlo
```text
.git
.git-old
.env
testdata/
```
Además de evitar fugas, el contexto de build pasa de 300 MB a unos KB.
:::

## Paso 5 · Despliega, escanea e inventaría

:::pista Cómo hacerlo
```bash
docker build -t tienda/api:2.0 ~/api
docker rm -f api && docker run -d --name api --restart unless-stopped -p 8080:8080 tienda/api:2.0
curl -s 'localhost:8080/api/precio?sku=1'
trivy image --severity HIGH,CRITICAL tienda/api:2.0 > ~/trivy-despues.txt
syft tienda/api:2.0 -o spdx-json > ~/sbom-api-2.0.json
```
:::

## Cómo actuar en una situación así

- Imagen final = lo mínimo para ejecutar. Herramientas de depuración, en
  una imagen `:debug` aparte (distroless la tiene), nunca en producción.
- Un secreto que llegó a una capa está filtrado: rótalo.
- Escanea en el pipeline y bloquea por severidad, con excepciones justificadas.

## Si te atascas

- `exec /api: no such file or directory`: el binario es dinámico; falta `CGO_ENABLED=0`.
- `go: downloading go1.2x`: pon `GOTOOLCHAIN=local` (usa el Go de la imagen, no descarga otro).
- trivy intenta descargar la base de datos: carga `/etc/profile.d/trivy.sh` (abre una shell nueva).
- trivy da `fanal.db: permission denied`: la caché la creó root. `sudo chown -R analista /opt/trivy-cache/fanal`.
