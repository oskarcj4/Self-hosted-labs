# Imagen de 1.2 GB con CVEs

> DevOps · Docker multi-stage · distroless · usuario no root · trivy · syft

## Escenario

La imagen `tienda/api:1.0` pesa más de un giga, el escáner la llena de
CVEs y corre como root (`~/ticket/SEC-142.txt`). El código es un binario Go
de unos pocos MB: todo lo demás sobra. Dentro van el compilador, Debian
completo, el código fuente, un volcado de producción de 300 MB y un `.env`
con una contraseña.

- **Multi-stage**: una etapa compila con todas las herramientas; la final
  sólo recibe el binario con `COPY --from=`.
- **Distroless**: imagen sin shell ni gestor de paquetes; sólo lo mínimo
  para ejecutar. `static-debian12:nonroot` ya trae el usuario `nonroot`
  (UID 65532).
- **.dockerignore**: lo que no se envía al build no puede acabar en la imagen.
- **trivy** busca CVEs; **syft** genera el SBOM (inventario de componentes).

Este lab tiene su propio Docker dentro del contenedor (no toca el de tu
máquina). Las dos bases que necesitas ya están cargadas (`docker images`):
no hace falta descargar nada.

## Objetivos

1. Mide la 1.0: tamaño y CVEs. Guarda el informe de trivy en `~/trivy-antes.txt`.
2. Reescribe `~/api/Dockerfile` en multi-stage: compila en
   `golang:1.22.5-bookworm`, ejecuta en `gcr.io/distroless/static-debian12:nonroot`,
   sin root. Añade `.dockerignore`.
3. Construye `tienda/api:2.0` (menos de 50 MB) y sustituye el contenedor
   `api` (puerto 8080) por la 2.0.
4. Escanea la 2.0 → `~/trivy-despues.txt`, y genera su SBOM con syft →
   `~/sbom-api-2.0.json` (SPDX o CycloneDX en JSON).

## Comandos que te pueden servir

```bash
docker images; docker history tienda/api:1.0
docker run --rm --entrypoint ls tienda/api:1.0 -la /src /src/testdata
trivy image tienda/api:1.0 > ~/trivy-antes.txt; grep Total ~/trivy-antes.txt
docker build -t tienda/api:2.0 ~/api
docker inspect -f '{{.Config.User}}' tienda/api:2.0
docker rm -f api && docker run -d --name api --restart unless-stopped -p 8080:8080 tienda/api:2.0
curl -s localhost:8080/health; curl -s 'localhost:8080/api/precio?sku=1'
trivy image --severity HIGH,CRITICAL tienda/api:2.0 > ~/trivy-despues.txt
syft tienda/api:2.0 -o spdx-json > ~/sbom-api-2.0.json
```

> Para un binario Go en distroless `static`: `CGO_ENABLED=0`. Si no, el
> binario busca la libc y no arranca ("no such file or directory").

## Cuando creas que terminaste

```bash
bash /opt/lab/check.sh
```
