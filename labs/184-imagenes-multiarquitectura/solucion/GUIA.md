# Resolución guiada · Lab 184

:::piensa ¿Qué significa `--platform=$BUILDPLATFORM`?
"Esta etapa corre en mi máquina, sea cual sea el destino". Es correcto para
compilar rápido, pero entonces **tú** tienes que decirle al compilador el
destino. Si no, `go build` compila para la máquina donde corre: amd64.
:::

## Paso 1 · Ver el problema

:::pista Qué mirar
```bash
docker buildx build --platform linux/amd64,linux/arm64 -t localhost:5000/hola:1.0 --push .
docker buildx imagetools inspect localhost:5000/hola:1.0
```
Salen las dos plataformas. Pero el binario de la variante arm64 es x86-64:
nadie lo nota hasta ejecutarlo en ARM.
:::

## Paso 2 · Compilar para el destino

:::pista Cómo hacerlo
```dockerfile
ARG TARGETOS TARGETARCH
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /hola .
```
`ARG` sin valor: buildx los rellena por plataforma. Tienen que declararse
**dentro** de la etapa que los usa.
:::

## Paso 3 · La versión

:::pista Cómo hacerlo
`ARG VERSION=dev` y `-ldflags "-X main.version=$VERSION"`; al construir,
`--build-arg VERSION=1.0`.
:::

## Cómo actuar en una situación así

- Prueba cada variante antes de dar la imagen por buena: en CI, un runner ARM o un `docker run --platform linux/arm64` con emulación.
- La imagen final `FROM scratch` (o distroless) no tiene `RUN`: no necesita emulación.
- Con C (CGO) o con `RUN apt-get` en la imagen final, la compilación cruzada se complica: entonces sí hace falta QEMU o runners nativos.
