#!/usr/bin/env bash
# Lab 184: los nuevos servidores (y los Mac del equipo) son ARM64. La imagen
# sólo existe para amd64, y el primer intento de multiplataforma "funciona"
# pero mete un binario amd64 dentro de la variante arm64.
set -e
A=/home/analista/hola
mkdir -p $A

docker run -d --name registro --restart unless-stopped -p 127.0.0.1:5000:5000 registry:2.8.3 >/dev/null

cat > $A/go.mod <<'G'
module tienda/hola

go 1.23
G
cat > $A/main.go <<'GO'
package main

import (
	"fmt"
	"runtime"
)

var version = "dev"

func main() {
	fmt.Printf("hola %s desde %s/%s\n", version, runtime.GOOS, runtime.GOARCH)
}
GO
# Primer intento de otro compañero: compila en la plataforma de construcción
# (rápido, sin emulación)... pero siempre para amd64.
cat > $A/Dockerfile <<'DF'
FROM --platform=$BUILDPLATFORM golang:1.23-alpine AS build
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /hola .

FROM scratch
COPY --from=build /hola /hola
ENTRYPOINT ["/hola"]
DF
chown -R analista:analista $A

cat > /home/analista/TAREA.txt <<'TXT'
TAREA · Imágenes multiarquitectura

Los servidores nuevos son ARM64 (y los portátiles del equipo, también).
Publica localhost:5000/hola:1.0 como imagen MULTIPLATAFORMA:

1. Una sola etiqueta con dos variantes: linux/amd64 y linux/arm64.
2. Cada variante con el binario de SU arquitectura (cuidado: el Dockerfile
   actual compila con el --platform de construcción...).
3. Sin emulación (no hay QEMU): compilación cruzada de Go con TARGETOS/TARGETARCH.
4. El binario lleva la versión: "hola 1.0 desde linux/amd64"
   (go build -ldflags "-X main.version=1.0").

Registro local en localhost:5000 (ya arrancado).
Comprueba:  bash /opt/lab/check.sh
TXT
chown analista:analista /home/analista/TAREA.txt
echo "Lab 184 plantado."
