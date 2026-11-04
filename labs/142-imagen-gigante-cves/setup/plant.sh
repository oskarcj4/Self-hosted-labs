#!/usr/bin/env bash
# Lab 142: la API de precios se construye sobre golang:bookworm completo,
# copia todo el directorio (con un volcado de 300 MB) y corre como root.
set -e
P=/home/analista/api
mkdir -p "$P/testdata" "$P/.git-old"
cd "$P"
cat > go.mod <<'MOD'
module tienda/api

go 1.22
MOD
cat > main.go <<'GO'
package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
)

var version = "dev"

func main() {
	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte("ok\n"))
	})
	http.HandleFunc("/api/precio", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]any{
			"sku": r.URL.Query().Get("sku"), "precio": 19.99, "version": version, "uid": os.Getuid(),
		})
	})
	log.Println("api escuchando en :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
GO
cat > Dockerfile <<'DF'
FROM golang:1.22.5-bookworm
WORKDIR /src
COPY . .
RUN go build -o /usr/local/bin/api .
EXPOSE 8080
CMD ["api"]
DF
# Volcado de producción "para los tests" y restos de un repo viejo: nadie los excluyó.
head -c 300M /dev/urandom > testdata/dump-produccion.sql.gz
echo "DB_PASSWORD=Pr0d-2026!" > .env
head -c 20M /dev/urandom > .git-old/pack-viejo.pack

export GOTOOLCHAIN=local
docker build -q -t tienda/api:1.0 . >/dev/null
docker run -d --name api --restart unless-stopped -p 8080:8080 tienda/api:1.0 >/dev/null
chown -R analista:analista "$P"

mkdir -p /home/analista/ticket
cat > /home/analista/ticket/SEC-142.txt <<'TXT'
SEC-142 · imagen tienda/api:1.0
- Pesa más de un giga: cada despliegue tarda minutos en descargarla.
- El escáner de seguridad la marca con cientos de CVEs.
- Corre como root y lleva dentro el compilador, el código, un volcado de
  producción y un .env con la contraseña de la base de datos.

Entrega tienda/api:2.0:
1. Mide la 1.0: tamaño (docker images) y CVEs -> ~/trivy-antes.txt
2. Dockerfile multi-stage: compila en golang, ejecuta en distroless
   (gcr.io/distroless/static-debian12:nonroot), sin root, con .dockerignore.
3. Sustituye el contenedor 'api' por la 2.0 en el puerto 8080.
4. Escanea la 2.0 -> ~/trivy-despues.txt  y genera su SBOM con syft
   -> ~/sbom-api-2.0.json (SPDX o CycloneDX en JSON).
TXT
chown -R analista:analista /home/analista/ticket
echo "Lab 142 plantado."
