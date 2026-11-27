# Resolución guiada · Lab 184

:::piensa Una etiqueta, varias imágenes
Una imagen multiplataforma es un **índice**: una sola etiqueta
(`hola:1.0`) que apunta a una imagen distinta por arquitectura. Cada máquina
descarga la suya. Construirla bien tiene una trampa: con
`--platform=$BUILDPLATFORM`, la etapa de compilación corre en **tu** máquina
(rápido, sin emulación), pero entonces tienes que decirle al compilador el
destino. Si no, compila para la máquina donde corre, y la variante "arm64"
lleva dentro un binario amd64.
:::

**El plan:** (1) ver el problema, (2) escribir el Dockerfile con compilación
cruzada, (3) construir y publicar, y (4) comprobar cada variante.

## Paso 1 · El problema

:::pista Cómo hacerlo
```bash
cd ~/hola
cat Dockerfile
docker buildx ls
```
`docker buildx` es el constructor moderno de Docker; `ls` enseña los
constructores disponibles y para qué plataformas pueden construir.

**Qué deberías ver:** un Dockerfile con `FROM --platform=$BUILDPLATFORM` y un
`go build` sin `GOOS`/`GOARCH`. Las dos variantes saldrán con un binario para
la plataforma del constructor.
:::

## Paso 2 · Compilación cruzada

:::pista Cómo hacerlo
`Dockerfile`:
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

| Pieza | Qué hace |
|---|---|
| `FROM --platform=$BUILDPLATFORM` | Esta etapa usa la imagen de **tu** arquitectura: corre nativa, sin emular. |
| `ARG TARGETOS TARGETARCH` | buildx rellena estas variables con la plataforma destino de cada variante (`linux`, `arm64`…). Hay que declararlas **dentro** de la etapa que las usa. |
| `GOOS=… GOARCH=…` | Le dicen a Go para qué sistema y arquitectura compilar. Go compila en cruzado sin herramientas extra. |
| `CGO_ENABLED=0` | Binario estático, sin depender de la biblioteca C (necesario para `scratch`). |
| `-X main.version=$VERSION` | Fija la variable `version` del programa al compilar. |
| `FROM scratch` | Imagen final vacía: sólo el binario. Como no tiene `RUN`, construirla para arm64 tampoco necesita emulación. |
:::

## Paso 3 · Construye y publica

:::pista Cómo hacerlo
```bash
docker buildx build --platform linux/amd64,linux/arm64 --build-arg VERSION=1.0 \
  -t localhost:5000/hola:1.0 --push .
docker buildx imagetools inspect localhost:5000/hola:1.0
```
- `--platform a,b` construye una variante por plataforma.
- `--push` sube el índice y las variantes al registro (un índice multiplataforma
  no se puede guardar en el Docker local, sólo en un registro).
- `imagetools inspect` enseña el índice: las plataformas y el digest de cada una.

**Qué deberías ver:** `Platform: linux/amd64` y `Platform: linux/arm64`, cada
una con su digest.
:::

## Paso 4 · Comprueba cada variante

**Pregúntate:** el índice dice "arm64", pero ¿lo es el binario de dentro?

:::pista Cómo hacerlo
Extrae cada variante a una carpeta y mira el binario con `file`:
```bash
for p in amd64 arm64; do
  docker buildx build --platform linux/$p --build-arg VERSION=1.0 -o type=local,dest=/tmp/hola-$p .
  file /tmp/hola-$p/hola
done
docker run --rm --pull always localhost:5000/hola:1.0
bash /opt/lab/check.sh
```
`-o type=local,dest=…` escribe el resultado del build como ficheros en vez de
como imagen. `file` dice para qué arquitectura es un ejecutable.

**Qué deberías ver:** `x86-64` en uno y `ARM aarch64` en el otro, y
`hola 1.0 desde linux/amd64` al ejecutar.
:::

## Cómo actuar en una situación así

- Prueba cada variante antes de darla por buena: en CI, un runner ARM o
  `file` sobre el binario, como aquí.
- Con C (CGO) o con `RUN apt-get` en la imagen final, la compilación cruzada se
  complica; ahí sí hacen falta QEMU o runners nativos.
- Una sola etiqueta para todas las arquitecturas simplifica los despliegues:
  el mismo manifiesto sirve en x86 y en ARM.

## Si te atascas

- **Las dos variantes salen `x86-64`:** faltan `GOOS`/`GOARCH`, o el `ARG
  TARGETOS TARGETARCH` está antes del `FROM`.
- **`exec format error` al construir:** algún `RUN` se ejecuta en la plataforma
  destino (falta `--platform=$BUILDPLATFORM` en esa etapa).
- **`--push` falla:** comprueba el registro con `curl -s localhost:5000/v2/`.
