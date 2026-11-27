# Resolución guiada · Lab 142

:::piensa Lo que no está, no se puede atacar
Una imagen grande no es sólo lenta de descargar: cada paquete que lleva y no
usas es un CVE que tendrás que justificar, y cada fichero que copiaste sin
querer puede ser un secreto. La API es un binario de Go de unos pocos MB.
Para **compilarla** hace falta mucho; para **ejecutarla**, casi nada. La idea
es separar esas dos cosas.
:::

**El plan:** (1) medir de dónde salen los 1,2 GB, (2) escanear los CVEs,
(3) reescribir el `Dockerfile` en dos etapas, (4) excluir lo que no debe entrar
en el build y (5) desplegar, escanear y generar el inventario (SBOM).

## Paso 1 · ¿De dónde salen los 1,2 GB?

**Objetivo:** saber qué ocupa la imagen antes de recortarla.

:::pista Cómo hacerlo
```bash
docker images tienda/api
docker history tienda/api:1.0
docker run --rm --entrypoint ls tienda/api:1.0 -la /src /src/testdata
```
- `docker history` lista las capas con el tamaño que añadió cada una.
- `--entrypoint ls` sustituye el programa de arranque de la imagen por `ls`
  (los argumentos van después del nombre de la imagen). Así miras dentro sin
  arrancar la API. `--rm` borra el contenedor al terminar.

**Qué deberías ver:** la base `golang` (~800 MB: Debian completo más el
compilador) y una capa `COPY . .` de unos 320 MB, con el volcado de
`testdata/`, el repo viejo `.git-old/` y el `.env` con la contraseña.
:::

## Paso 2 · ¿Cuántos CVEs y de dónde?

**Objetivo:** el informe "antes", para comparar después.

:::pista Cómo hacerlo
```bash
trivy image tienda/api:1.0 > ~/trivy-antes.txt
grep -E '^Total|^tienda|^usr' ~/trivy-antes.txt
```
**trivy** compara cada paquete que encuentra en la imagen con una base de
datos de vulnerabilidades conocidas (CVE). En este lab la base ya viene
descargada: `/etc/profile.d/trivy.sh` le dice que no intente actualizarla.

**Qué deberías ver:** cientos de CVEs en la sección del sistema operativo
(Debian). Casi todos son de paquetes que la API ni usa.
:::

## Paso 3 · Multi-stage: compilar en una imagen, ejecutar en otra

**Objetivo:** que la imagen final sólo contenga el binario.

**Pregúntate:** ¿qué necesita la API para **compilarse**? ¿Y para
**ejecutarse**?

:::pista Cómo hacerlo
Sustituye `~/api/Dockerfile`:
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
EXPOSE 8080
ENTRYPOINT ["/api"]
```

Hay dos `FROM`: cada uno empieza una **etapa** nueva. La imagen final es la
última; la primera sólo existe durante el build.

| Pieza | Por qué |
|---|---|
| `AS build` | Da nombre a la primera etapa para poder copiar de ella después. |
| `CGO_ENABLED=0` | Compila un binario **estático**, que no necesita la biblioteca C del sistema. Imprescindible: la imagen final no la tiene. |
| `GOTOOLCHAIN=local` | Usa el Go que trae la imagen. Si no, Go podría intentar descargar otra versión (y aquí no hay Internet). |
| `COPY go.mod` → `go mod download` → `COPY *.go` | Docker reutiliza capas mientras no cambie lo que copian. Si sólo cambias código, la descarga de dependencias no se repite. |
| `-trimpath -ldflags="-s -w"` | Quita del binario las rutas de tu máquina y la información de depuración: más pequeño. |
| `FROM …/distroless/static-debian12:nonroot` | Imagen mínima de Google: sin shell, sin gestor de paquetes, casi sin ficheros. Sólo lo justo para un binario estático. |
| `COPY --from=build` | Copia **desde la etapa `build`**, no desde tu carpeta. Sólo el binario pasa a la imagen final. |
| `USER nonroot:nonroot` | La imagen ya trae ese usuario (UID 65532). La API deja de correr como root. |
| `ENTRYPOINT ["/api"]` | El formato con corchetes ejecuta el binario directamente. El otro formato necesitaría `/bin/sh`, que aquí no existe. |
:::

## Paso 4 · `.dockerignore`

**Objetivo:** que el volcado, el repo viejo y el `.env` no lleguen ni al build.

**Pregúntate:** si el `Dockerfile` nuevo ya sólo copia `go.mod` y `*.go`, ¿para
qué sirve excluir nada?

:::pista Cómo hacerlo
```bash
cat > ~/api/.dockerignore <<'EOF'
.git
.git-old
.env
testdata/
EOF
```
Al hacer `docker build`, el cliente envía **toda la carpeta** (el *contexto*)
al motor de Docker antes de leer el `Dockerfile`. `.dockerignore` decide qué no
se envía. Sirve para dos cosas: el build no arrastra 320 MB cada vez, y si
mañana alguien vuelve a escribir `COPY . .`, el `.env` y el volcado
seguirán fuera.
:::

## Paso 5 · Despliega, escanea e inventaría

:::pista Cómo hacerlo
```bash
docker build -t tienda/api:2.0 ~/api
docker images tienda/api
docker rm -f api
docker run -d --name api --restart unless-stopped -p 8080:8080 tienda/api:2.0
curl -s 'localhost:8080/api/precio?sku=1'
```
- `docker rm -f` para y borra el contenedor viejo (necesitas su nombre y su
  puerto libres).
- `--restart unless-stopped`: Docker lo vuelve a arrancar si se cae o si se
  reinicia la máquina, salvo que lo pares tú.

**Qué deberías ver:** la 2.0 en unos 8 MB y la respuesta con `"uid":65532`.
Después:
```bash
trivy image --severity HIGH,CRITICAL tienda/api:2.0 > ~/trivy-despues.txt
syft tienda/api:2.0 -o spdx-json > ~/sbom-api-2.0.json
bash /opt/lab/check.sh
```
- `--severity HIGH,CRITICAL` muestra sólo lo grave.
- **syft** genera el **SBOM** (*Software Bill of Materials*): el inventario de
  todo lo que lleva la imagen. `-o spdx-json` lo escribe en el formato estándar
  SPDX. Cuando salga un CVE nuevo, buscarás en los SBOM en vez de escanear
  todas las imágenes otra vez.
:::

:::ojo Lo que trivy sigue viendo
En la 2.0 ya no hay paquetes del sistema, pero trivy puede seguir listando
CVEs de la **biblioteca estándar de Go 1.22.5** que va dentro del binario.
Eso no se arregla con otra base: se arregla compilando con un Go más nuevo.
Una imagen mínima reduce la superficie; no sustituye a actualizar.
:::

## Cómo actuar en una situación así

- Imagen final = lo mínimo para ejecutar. Para depurar, distroless ofrece una
  variante `:debug` con shell, que no se despliega en producción.
- El `.env` estuvo en una capa de la 1.0: la contraseña está filtrada.
  **Rótala.**
- Escanea en el pipeline y bloquea por severidad, con excepciones justificadas.

## Si te atascas

- **`exec /api: no such file or directory`:** el binario es dinámico y busca
  la biblioteca C, que no existe en distroless. Falta `CGO_ENABLED=0`.
- **`go: downloading go1.2x`:** falta `GOTOOLCHAIN=local`.
- **trivy intenta descargar la base de datos:** abre una terminal nueva para
  que cargue `/etc/profile.d/trivy.sh`.
- **trivy da `fanal.db: permission denied`:** la caché la creó root.
  `sudo chown -R analista /opt/trivy-cache/fanal`.
