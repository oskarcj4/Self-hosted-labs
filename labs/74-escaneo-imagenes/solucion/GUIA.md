# Resolución guiada · Escaneo de imágenes: a 0 CRITICAL

:::piensa Antes de tocar nada
El gate de CI bloquea con cualquier CVE CRITICAL. La pregunta clave no es
"cuántos" sino "**de dónde**": mira la columna del paquete. Si los CRITICAL
vienen del sistema base (openssl, busybox, sqlite...), el problema es la
**imagen base**, no tu código: subirla se los lleva casi todos de un plumazo. Y
el arreglo va en el **Dockerfile versionado**, no en una imagen suelta que el
próximo build pisa.
:::

## Paso 1 · Escanea y lee de dónde salen

**Pregúntate:** ¿los CRITICAL son de tu app o del sistema base?

:::pista Cómo verlo
```bash
cd /srv/api
grype inventario-api:local -o json \
  | jq -r '.matches[] | [.vulnerability.severity, .artifact.name, .vulnerability.id] | @tsv' \
  | sort | grep -i critical
# Critical busybox ... / Critical openssl ... / Critical libcrypto3 ...  -> todos del base
head -3 Dockerfile
# FROM python:3.12.0-alpine3.18   <- base vieja (Alpine 3.18)
```
:::

## Paso 2 · Sube la imagen base (en el Dockerfile)

**Pregúntate:** ¿qué bases mantenidas hay precargadas?

:::pista Cómo hacerlo
```bash
docker images | grep python     # python:3.12-alpine (mantenida) disponible
sed -i 's#^FROM python:3.12.0-alpine3.18#FROM python:3.12-alpine#' Dockerfile
docker build -t inventario-api:local .
grype inventario-api:local | grep -i critical     # (vacío: 0 Critical)
docker run --rm inventario-api:local              # inventario-api ok
```
Los CRITICAL eran fallos del sistema de la imagen, ya parcheados por los
mantenedores. Tu código no cambia.
:::

## Verifica

```bash
bash /opt/lab/check.sh
```

## Por qué así (y no de otras formas)

- **En el Dockerfile, no parcheando una imagen a mano**: el build la reconstruye
  cada vez; sin versionar, el arreglo se pierde.
- **Fija la base** (`python:3.12-alpine` o, mejor, por digest `@sha256:...`)
  para builds reproducibles, y **re-escanea periódicamente**: una imagen limpia
  hoy acumula CVE sin tocar una línea.
- **0 CRITICAL como gate**, no "lo revisamos luego": el umbral que bloquea el
  merge es lo que frena la deuda de seguridad.
- **Mismo método para tus dependencias**: `grype dir:.` sobre
  `requirements.txt`/`package-lock.json`; sube de versión y re-escanea.

## Sobre el escáner mismo

grype está **fijado a una versión** e instalado verificando su **checksum**, con
la base de CVE en local. Un escáner es código con mucho privilegio en el
pipeline: trátalo como dependencia crítica (versión fijada, checksum, origen de
confianza), no lo bajes "a pelo" cada vez (lab 77).

## Si te atascas

- Siguen saliendo CRITICAL → ¿reconstruiste la imagen (`docker build`) tras
  editar el Dockerfile? ¿quedan CVE de **tus** deps? Escanéalas aparte.
- La app ya no arranca tras cambiar la base → revisa que la nueva base trae tus
  dependencias de sistema; añade las que falten en el Dockerfile.
