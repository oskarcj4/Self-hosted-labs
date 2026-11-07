# Imágenes multiarquitectura con buildx

> DevOps · contenedores · buildx · índice de imágenes · BUILDPLATFORM/TARGETARCH · compilación cruzada

## Escenario

Los servidores nuevos son **ARM64** (Graviton, Ampere), igual que los
portátiles del equipo. La imagen `hola` sólo existe para amd64: en ARM, o no
arranca (`exec format error`) o va emulada y lenta.

Una imagen multiplataforma es un **índice**: una sola etiqueta que apunta a
una variante por plataforma. Cada máquina descarga la suya.

Construir para otra arquitectura tiene dos caminos:

- **Emular** (QEMU): sencillo, pero lento, y aquí no está instalado.
- **Compilar en cruzado**: la etapa de compilación corre en la plataforma de
  construcción (`$BUILDPLATFORM`) y produce el binario para la de destino
  (`$TARGETOS`/`$TARGETARCH`). Go lo hace de serie.

El primer intento de un compañero ya usa `--platform=$BUILDPLATFORM`... y
deja un binario amd64 dentro de la variante arm64. La etiqueta "funciona",
hasta que alguien la ejecuta en ARM.

Docker corre **dentro** del lab, con un registro en `localhost:5000`.

## Objetivos

1. `localhost:5000/hola:1.0`: índice con `linux/amd64` y `linux/arm64`.
2. Cada variante con el binario de **su** arquitectura.
3. Sin emulación.
4. `docker run` en amd64 imprime `hola 1.0 desde linux/amd64`.

## Pistas

```bash
cd ~/hola
docker buildx ls
docker buildx build --platform linux/amd64,linux/arm64 -t localhost:5000/hola:1.0 --push .
docker buildx imagetools inspect localhost:5000/hola:1.0
```

```dockerfile
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
ARG TARGETOS TARGETARCH          # buildx los rellena para cada plataforma
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build ...
```

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
